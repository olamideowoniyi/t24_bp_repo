#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV=${ENV:-dev}
ENV_CONFIG="$SCRIPT_DIR/env/$ENV.conf"

if [ ! -f "$ENV_CONFIG" ]; then
    echo "ERROR: Config not found: $ENV_CONFIG"
    exit 1
fi

# Load config
while IFS='=' read -r key value; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    export "$key=$value"
done < "$ENV_CONFIG"

T24_LOCAL="$BNK_HOME/local"
JARS_DIR="$TAFJ_HOME/data/tafj/jars"
BP_DIR="$SCRIPT_DIR/../bp"

echo ""
echo "=> T24 BASIC Compilation [ENV: $ENV]"
echo "=> Source : $BP_DIR"
echo "=> TAFJ   : $TAFJ_HOME"
echo "=> Output : $T24_LOCAL"
echo ""

mkdir -p "$T24_LOCAL"

COMPILED=0
FAILED=0

for F in "$BP_DIR"/*.b; do
    [ -f "$F" ] || { echo "No .b files found in $BP_DIR"; exit 1; }
    echo "   Compiling: $(basename "$F")"
    if "$TAFJ_HOME/bin/tCompile" "$F"; then
        COMPILED=$((COMPILED + 1))
    else
        echo "   ERROR: $(basename "$F")"
        FAILED=$((FAILED + 1))
    fi
done

if [ "$COMPILED" -eq 0 ] && [ "$FAILED" -eq 0 ]; then
    echo "No .b files found in $BP_DIR"
    exit 1
fi

echo ""
echo "=> Copying JARs to $T24_LOCAL"
COPIED=0
for J in "$JARS_DIR"/*.jar; do
    [ -f "$J" ] || continue
    cp -f "$J" "$T24_LOCAL/"
    echo "   Copied: $(basename "$J")"
    COPIED=$((COPIED + 1))
done

echo ""
echo "=> Done: $COMPILED compiled, $FAILED failed, $COPIED jar(s) ready"
[ "$FAILED" -gt 0 ] && exit 1
exit 0
