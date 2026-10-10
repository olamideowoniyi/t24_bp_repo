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

JARS_DIR="$TAFJ_HOME/data/tafj/jars"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Last commit successfully deployed to this environment (written by deploy.sh)
MARKER="$BNK_HOME/.cicd/last_deployed_$ENV.txt"

echo ""
echo "=> T24 BASIC Compilation [ENV: $ENV]"
echo "=> Repo      : $REPO_ROOT"
echo "=> BNK_HOME  : $BNK_HOME"
echo "=> TAFJ      : $TAFJ_HOME"
[ "$DRY_RUN" = "1" ] && echo "=> DRY RUN   : nothing will be copied or compiled"
echo ""

# -----------------------------------------------------------------------------
# Work out what changed since the last successful deploy to this environment.
# Falls back to the previous commit when there is no record yet.
# -----------------------------------------------------------------------------
BASE=""
[ -f "$MARKER" ] && BASE="$(tr -d '[:space:]' < "$MARKER")"
if [ -n "$BASE" ] && ! git -C "$REPO_ROOT" cat-file -e "$BASE" 2>/dev/null; then
    echo "   WARNING: last deployed commit $BASE not found in history - using previous commit"
    BASE=""
fi
if [ -z "$BASE" ]; then
    if git -C "$REPO_ROOT" rev-parse --verify --quiet HEAD~1 >/dev/null; then
        BASE="HEAD~1"
    else
        BASE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"   # empty tree: first commit
    fi
fi
echo "=> Changes since: $BASE"

mapfile -t CHANGED < <(git -C "$REPO_ROOT" -c core.quotepath=off diff --name-only --diff-filter=ACMR "$BASE" HEAD -- bp)
mapfile -t DELETED < <(git -C "$REPO_ROOT" -c core.quotepath=off diff --name-only --diff-filter=D "$BASE" HEAD -- bp)

# -----------------------------------------------------------------------------
# Sync every changed file under bp/ to the same place under BNK_HOME
# (routines, .component files, inserts) and sort what needs compiling.
#   bp/UD/AUTH.BP/X.b  ->  $BNK_HOME/UD/AUTH.BP/X.b
# -----------------------------------------------------------------------------
COMPONENTS=()
ROUTINES=()
for F in "${CHANGED[@]}"; do
    REL="${F#bp/}"
    DEST="$BNK_HOME/$REL"
    if [ "$DRY_RUN" = "1" ]; then
        echo "   [dry-run] sync: $REL"
    else
        mkdir -p "$(dirname "$DEST")"
        cp -f "$REPO_ROOT/$F" "$DEST"
        echo "   Synced: $REL"
    fi
    case "$DEST" in
        *.component) COMPONENTS+=("$DEST") ;;
        *.b)         ROUTINES+=("$DEST") ;;
    esac
done

for D in "${DELETED[@]}"; do
    echo "   NOTE: deleted in repo, left on server: $D"
done

if [ "${#CHANGED[@]}" -eq 0 ]; then
    echo "   No changed files under bp/ - nothing to compile"
    exit 0
fi
echo ""
echo "=> Changed: ${#CHANGED[@]} file(s), ${#COMPONENTS[@]} component(s), ${#ROUTINES[@]} routine(s)"

# Compile in batches of 20 per tCompile call (one TAFJ start-up per batch).
FAILED=0
compile_batch() {
    local label="$1"; shift
    echo ""
    echo "=> Compiling $label batch: $*"
    [ "$DRY_RUN" = "1" ] && return 0
    if ! "$TAFJ_HOME/bin/tCompile" "$@"; then
        echo "   ERROR: compilation errors in this $label batch"
        FAILED=$((FAILED + 1))
    fi
}
compile_list() {
    local label="$1"; shift
    local items=("$@")
    local i
    for ((i = 0; i < ${#items[@]}; i += 20)); do
        compile_batch "$label" "${items[@]:i:20}"
    done
}

# New routines come with their .component - compile components first so the
# component jar exists, then the routines (TAFJ updates the jar for each class).
compile_list "component" "${COMPONENTS[@]}"
compile_list "routine" "${ROUTINES[@]}"

echo ""
if [ "$FAILED" -gt 0 ]; then
    echo "=> Result: compilation FAILED - see errors above"
    exit 1
fi

echo "=> Result: ${#COMPONENTS[@]} component(s), ${#ROUTINES[@]} routine(s) compiled, 0 failed"
echo ""
echo "=> JARs in $JARS_DIR:"
for J in "$JARS_DIR"/*.jar; do
    [ -f "$J" ] && echo "   $(basename "$J")"
done

exit 0
