#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV=${ENV:-dev}
ENV_CONFIG="$SCRIPT_DIR/env/$ENV.conf"

if [ ! -f "$ENV_CONFIG" ]; then
    echo "ERROR: Config not found: $ENV_CONFIG"
    exit 1
fi

while IFS='=' read -r key value; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    export "$key=$value"
done < "$ENV_CONFIG"

JARS_DIR="$TAFJ_HOME/data/tafj/jars"
MODULE_XML="$JBOSS_HOME/modules/com/temenos/t24/main/module.xml"

echo ""
echo "=> T24 Deploy [ENV: $ENV]"
echo "=> JBoss local : $JBOSS_MODULE_LOCAL"
echo "=> module.xml  : $MODULE_XML"
echo ""

if [ ! -f "$MODULE_XML" ]; then
    echo "ERROR: module.xml not found: $MODULE_XML"
    exit 1
fi

# Ensure JBoss local folder exists
mkdir -p "$JBOSS_MODULE_LOCAL"

# Check if JBOSS_MODULE_LOCAL is a symlink - if so, skip the copy
LINKED=0
[ -L "$JBOSS_MODULE_LOCAL" ] && LINKED=1
[ "$LINKED" -eq 1 ] && echo "   Note: JBoss local is a symlink - skipping copy"

echo "=> Deploying JARs..."
DEPLOYED=0
for J in "$JARS_DIR"/*.jar; do
    [ -f "$J" ] || continue
    JAR="$(basename "$J")"

    if [ "$LINKED" -eq 0 ]; then
        cp -f "$J" "$JBOSS_MODULE_LOCAL/"
    fi

    LOCAL_ENTRY="    <resource-root path=\"./local/$JAR\" />"
    T24LIB_ENTRY="    <resource-root path=\"./t24lib/$JAR\" />"

    if grep -qF "./local/$JAR" "$MODULE_XML" 2>/dev/null; then
        echo "   Already registered: $JAR"
    elif grep -qF "./t24lib/$JAR" "$MODULE_XML" 2>/dev/null; then
        # Insert ./local/ before the ./t24lib/ entry so our version wins
        sed -i "s|$T24LIB_ENTRY|$LOCAL_ENTRY\n$T24LIB_ENTRY|" "$MODULE_XML"
        echo "   Registered (override): $JAR"
    else
        sed -i "s|</resources>|$LOCAL_ENTRY\n  </resources>|" "$MODULE_XML"
        echo "   Registered: $JAR"
    fi

    DEPLOYED=$((DEPLOYED + 1))
done

if [ "$DEPLOYED" -eq 0 ]; then
    echo "   No JARs found in $JARS_DIR"
    exit 1
fi

echo ""
echo "=> Checking JBoss state [port $JBOSS_MGMT_PORT]..."
if nc -z localhost "$JBOSS_MGMT_PORT" 2>/dev/null; then
    echo "   JBoss running - reloading..."
    "$JBOSS_HOME/bin/jboss-cli.sh" --connect --command=":reload"
    echo "   Reload triggered"
else
    echo "   JBoss not running - JARs will load on next start"
fi

echo ""
echo "=> Deploy complete - $DEPLOYED jar(s) deployed"
exit 0
