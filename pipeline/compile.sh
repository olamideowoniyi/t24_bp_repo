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
BP_ROOT="$SCRIPT_DIR/../bp"
BP_ROOT="$(cd "$BP_ROOT" && pwd)"

echo ""
echo "=> T24 BASIC Compilation [ENV: $ENV]"
echo "=> Repo bp/  : $BP_ROOT"
echo "=> BNK_HOME  : $BNK_HOME"
echo "=> TAFJ      : $TAFJ_HOME"
echo ""

# Walk bp/ recursively - each subfolder mirrors BNK_HOME
# e.g. bp/T24_BP/AA.X.b    -> $BNK_HOME/T24_BP/AA.X.b
#      bp/UD/AUTH.BP/X.b   -> $BNK_HOME/UD/AUTH.BP/X.b

COMPILED=0
FAILED=0
SYNCED=0

while IFS= read -r -d '' F; do
    # Relative path from BP_ROOT
    REL="${F#$BP_ROOT/}"
    TARGET="$BNK_HOME/$REL"
    TARGET_DIR="$(dirname "$TARGET")"

    # Create target dir if missing
    mkdir -p "$TARGET_DIR"

    # Sync to BNK_HOME location
    cp -f "$F" "$TARGET"
    echo "   Synced: $REL"
    SYNCED=$((SYNCED + 1))

    # Compile from the BNK_HOME location
    echo "   Compiling: $REL"
    if "$TAFJ_HOME/bin/tCompile" "$TARGET"; then
        COMPILED=$((COMPILED + 1))
    else
        echo "   ERROR: $REL"
        FAILED=$((FAILED + 1))
    fi
    echo ""
done < <(find "$BP_ROOT" -name "*.b" -print0)

if [ "$SYNCED" -eq 0 ]; then
    echo "No .b files found under $BP_ROOT"
    exit 1
fi

echo ""
if [ "$FAILED" -gt 0 ]; then
    echo "=> Result: $COMPILED compiled, $FAILED FAILED"
    exit 1
fi

echo "=> Result: $COMPILED compiled, 0 failed"
echo ""
echo "=> JARs produced:"
for J in "$JARS_DIR"/*.jar; do
    [ -f "$J" ] && echo "   $(basename "$J")"
done

exit 0
