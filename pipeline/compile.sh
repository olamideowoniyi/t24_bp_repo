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

T24_BP="$BNK_HOME/T24_BP"
JARS_DIR="$TAFJ_HOME/data/tafj/jars"
SRC_DIR="$SCRIPT_DIR/../bp/src"

echo ""
echo "=> T24 BASIC Compilation [ENV: $ENV]"
echo "=> Source   : $SRC_DIR"
echo "=> T24_BP   : $T24_BP"
echo "=> TAFJ     : $TAFJ_HOME"
echo ""

if [ ! -d "$T24_BP" ]; then
    echo "ERROR: T24_BP not found: $T24_BP"
    exit 1
fi

# Sync .b files to T24_BP so tCompile can resolve INSERT references
echo "=> Syncing source files to T24_BP..."
SYNCED=0
for F in "$SRC_DIR"/*.b; do
    [ -f "$F" ] || { echo "   No .b files found in $SRC_DIR"; exit 1; }
    cp -f "$F" "$T24_BP/"
    echo "   Synced: $(basename "$F")"
    SYNCED=$((SYNCED + 1))
done

echo ""
echo "=> Compiling..."
COMPILED=0
FAILED=0
for F in "$SRC_DIR"/*.b; do
    [ -f "$F" ] || continue
    BN="$(basename "$F")"
    echo "   $BN"
    if "$TAFJ_HOME/bin/tCompile" "$T24_BP/$BN"; then
        COMPILED=$((COMPILED + 1))
    else
        echo "   ERROR compiling $BN"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
if [ "$FAILED" -gt 0 ]; then
    echo "=> Compile result: $COMPILED ok, $FAILED FAILED - aborting"
    exit 1
fi

echo "=> Compile result: $COMPILED compiled, 0 failed"
echo ""
echo "=> JARs produced in $JARS_DIR:"
for J in "$JARS_DIR"/*.jar; do
    [ -f "$J" ] && echo "   $(basename "$J")"
done

exit 0
