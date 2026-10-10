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
    export "$key=${value%$'\r'}"
done < "$ENV_CONFIG"

# Switches: config value, else default; a one-off override from the
# "Run workflow" button wins (Y/N; "config" or empty = use the config)
DEPLOY_TO_JBOSS=${DEPLOY_TO_JBOSS:-Y}
JBOSS_RELOAD=${JBOSS_RELOAD:-N}
case "${DEPLOY_OVERRIDE^^}" in Y|N) DEPLOY_TO_JBOSS="${DEPLOY_OVERRIDE^^}" ;; esac
case "${RELOAD_OVERRIDE^^}" in Y|N) JBOSS_RELOAD="${RELOAD_OVERRIDE^^}" ;; esac
DEPLOY_TO_JBOSS="${DEPLOY_TO_JBOSS^^}"
JBOSS_RELOAD="${JBOSS_RELOAD^^}"

JARS_DIR="$TAFJ_HOME/data/tafj/jars"
MODULE_XML="$JBOSS_HOME/modules/com/temenos/t24/main/module.xml"
CICD_DIR="$BNK_HOME/.cicd"
# Jars compiled while JBoss deploy was off - deployed by the next run with it on
PENDING="$CICD_DIR/pending_jboss_$ENV.txt"

WORK="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
JAR_LIST="$WORK/t24cicd_jars.txt"

mkdir -p "$CICD_DIR"

record_commit() {
    # Record this commit as deployed so the next run only compiles newer changes
    git -C "$SCRIPT_DIR/.." rev-parse HEAD > "$CICD_DIR/last_deployed_$ENV.txt"
    echo ""
    echo "=> Recorded deployed commit for $ENV"
}

echo ""
echo "=> T24 Deploy [ENV: $ENV]"
echo "=> Deploy to JBoss : $DEPLOY_TO_JBOSS"
echo "=> Reload JBoss    : $JBOSS_RELOAD"
echo "=> JBoss local     : $JBOSS_MODULE_LOCAL"
echo "=> module.xml      : $MODULE_XML"
echo ""

if [ ! -f "$JAR_LIST" ]; then
    echo "   WARNING: no jar list from the compile step - nothing new from this run"
    : > "$JAR_LIST"
fi

# Jars from this run plus any still pending from earlier compile-only runs
mapfile -t JARS < <(cat "$JAR_LIST" "$PENDING" 2>/dev/null | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort -u)

if [ "$DEPLOY_TO_JBOSS" = "N" ]; then
    # Keep the jars pending so the next run with JBoss deploy on picks them up
    printf '%s\n' "${JARS[@]}" | grep -v '^$' > "$PENDING" || true
    echo "=> JBoss deploy is OFF - compiled only: command-line TAFJ (tRun, DBTools) uses the new code, JBoss untouched"
    echo "   ${#JARS[@]} jar(s) waiting for JBoss:"
    for J in "${JARS[@]}"; do echo "      $J"; done
    record_commit
    exit 0
fi

if [ "${#JARS[@]}" -eq 0 ]; then
    echo "   No new jars - nothing to deploy to JBoss"
    record_commit
    exit 0
fi

if [ ! -f "$MODULE_XML" ]; then
    echo "ERROR: module.xml not found: $MODULE_XML"
    exit 1
fi

# Ensure JBoss local folder exists
mkdir -p "$JBOSS_MODULE_LOCAL"

# Check if JBOSS_MODULE_LOCAL is a symlink - if so, skip the copy
LINKED=0
if [ -L "$JBOSS_MODULE_LOCAL" ]; then
    LINKED=1
    echo "   Note: JBoss local is a symlink - skipping copy"
fi

echo "=> Deploying ${#JARS[@]} jar(s)..."
FAILED=0
for JAR in "${JARS[@]}"; do
    if [ ! -f "$JARS_DIR/$JAR" ]; then
        echo "   ERROR: jar not found: $JARS_DIR/$JAR"
        FAILED=$((FAILED + 1))
        continue
    fi

    if [ "$LINKED" -eq 0 ]; then
        if cp -f "$JARS_DIR/$JAR" "$JBOSS_MODULE_LOCAL/"; then
            echo "   Copied: $JAR"
        else
            echo "   ERROR: copy failed: $JAR"
            FAILED=$((FAILED + 1))
            continue
        fi
    fi

    # Add the module.xml entry only if it is not there yet
    LOCAL_ENTRY="    <resource-root path=\"./local/$JAR\" />"
    T24LIB_ENTRY="    <resource-root path=\"./t24lib/$JAR\" />"
    if grep -qF "./local/$JAR" "$MODULE_XML"; then
        echo "   Already registered: $JAR"
    elif grep -qF "./t24lib/$JAR" "$MODULE_XML"; then
        # Insert ./local/ before the ./t24lib/ entry so our version wins
        sed -i "s|$T24LIB_ENTRY|$LOCAL_ENTRY\n$T24LIB_ENTRY|" "$MODULE_XML"
        echo "   Registered (override): $JAR"
    else
        sed -i "s|</resources>|$LOCAL_ENTRY\n  </resources>|" "$MODULE_XML"
        echo "   Registered: $JAR"
    fi
done

if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo "=> Deploy FAILED for $FAILED jar(s) - pending list kept, commit not recorded"
    exit 1
fi

# Everything pending is now in JBoss
rm -f "$PENDING"

echo ""
if [ "$JBOSS_RELOAD" != "Y" ]; then
    echo "   JBoss reload is OFF - new jars load at the next JBoss restart"
else
    echo "=> Checking JBoss state [port $JBOSS_MGMT_PORT]..."
    if nc -z localhost "$JBOSS_MGMT_PORT" 2>/dev/null; then
        echo "   JBoss running - reloading..."
        "$JBOSS_HOME/bin/jboss-cli.sh" --connect --command=":reload"
        echo "   Reload triggered"
    else
        echo "   JBoss not running - jars will load on next start"
    fi
fi

record_commit
exit 0
