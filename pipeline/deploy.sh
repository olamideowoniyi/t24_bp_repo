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

T24_LOCAL="$BNK_HOME/local"
MODULE_XML="$JBOSS_HOME/modules/com/temenos/t24/main/module.xml"

echo ""
echo "=> Deploying JARs [ENV: $ENV]"

for J in "$T24_LOCAL"/*.jar; do
    [ -f "$J" ] || continue
    JAR=$(basename "$J")
    if grep -q "$JAR" "$MODULE_XML" 2>/dev/null; then
        echo "   Already registered: $JAR"
    else
        sed -i "s|</resources>|  <resource-root path=\"./local/$JAR\" />\n  </resources>|" "$MODULE_XML"
        echo "   Registered: $JAR"
    fi
done

echo ""
echo "=> Checking JBoss state..."
if nc -z localhost "$JBOSS_MGMT_PORT" 2>/dev/null; then
    echo "   JBoss running - reloading..."
    "$JBOSS_HOME/bin/jboss-cli.sh" --connect --command=":reload"
    echo "   Reload triggered"
else
    echo "   JBoss not running - JARs will be picked up on next start"
fi

echo ""
echo "=> Deploy complete"
