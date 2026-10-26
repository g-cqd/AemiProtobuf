#!/bin/sh
# The formal models: Lean 4 proofs, TLA+ specifications checked by TLC, and the modeler concurrency check.
#
#   Scripts/model.sh          run all three
#   Scripts/model.sh lean | tla | modeler
#
# Lean:    `lake build --wfail` in Models/lean, and no `sorry` anywhere: an unfinished proof is a failure, not a warning.
# TLA+:    every Models/tla/*.cfg is run with TLC; the run must say "No error has been found".
# modeler: `modeler check --strict Sources` reports an `await` or lock gap between a check and the write it guards. The wire core
#          has no actor, lock or `await`, so it finds nothing today; the gate is there for the types roadmap 0003 and 0009 add.
#          When it reports, `modeler tla --type T` writes a model for TLC (see Models/README.md).
# Exit: 0 all hold, 1 a model or proof failed, 2 a tool is missing.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

fail() { printf '[FAIL] %s\n' "$1" >&2; exit "${2:-1}"; }

run_lean() {
    command -v lake >/dev/null 2>&1 || LAKE="$HOME/.elan/bin/lake"
    LAKE="${LAKE:-lake}"
    [ -x "$(command -v "$LAKE" 2>/dev/null || echo "$LAKE")" ] || fail "lake (Lean 4, via elan) is not installed" 2
    printf '==> lean: lake build --wfail\n'
    if grep -rn --include='*.lean' -w 'sorry' Models/lean/AemiProtobufModels Models/lean/AemiProtobufModels.lean; then
        fail "a Lean file contains sorry"
    fi
    (cd Models/lean && "$LAKE" build --wfail) || fail "a Lean proof does not check"
}

run_tla() {
    command -v java >/dev/null 2>&1 || fail "java is needed to run TLC" 2
    jar=$(Scripts/tools.sh path tla2tools) || exit 2
    for cfg in Models/tla/*.cfg; do
        module="${cfg%.cfg}"
        printf '==> tlc: %s\n' "$(basename "$module")"
        out=$(mktemp)
        # `-metadir` keeps TLC's state files out of the repository.
        if ! (cd Models/tla && java -XX:+UseParallelGC -cp "$jar" tlc2.TLC -workers auto \
                -metadir "${TMPDIR:-/tmp}/aemiprotobuf-tlc" -config "$(basename "$cfg")" "$(basename "$module").tla") >"$out" 2>&1; then
            cat "$out" >&2; rm -f "$out"; fail "TLC found a violation in $module"
        fi
        grep -q 'No error has been found' "$out" || { cat "$out" >&2; rm -f "$out"; fail "TLC did not finish cleanly on $module"; }
        grep -E 'distinct states found|Finished in' "$out" | tail -2
        rm -f "$out"
    done
}

run_modeler() {
    modeler=$(Scripts/tools.sh path modeler) || exit 2
    printf '==> modeler check --strict Sources\n'
    "$modeler" check --strict Sources || fail "modeler found a check-then-write gap"
}

case "${1:-all}" in
    lean) run_lean ;;
    tla) run_tla ;;
    modeler) run_modeler ;;
    all) run_lean; run_tla; run_modeler ;;
    *) fail "usage: model.sh [lean|tla|modeler]" 2 ;;
esac
printf '[OK] models hold\n'
