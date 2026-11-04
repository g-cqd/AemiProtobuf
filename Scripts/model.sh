#!/bin/sh
# The formal models: Lean 4 proofs and TLA+ specifications checked by TLC.
#
#   Scripts/model.sh          run both
#   Scripts/model.sh lean | tla
#
# Lean: `lake build --wfail` in Models/lean, and no `sorry` anywhere: an unfinished proof is a failure, not a warning.
# TLA+: swift-ci's `tla-models` command (.ci/action.json): every Models/tla/*.cfg with the pinned TLC, each run in a state
#       directory of its own; a `.buggy.cfg` must be refuted.
# The modeler concurrency check is in quality (`.ci/swift-ci run quality`), with swift-ci's pinned modeler.
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
    "$ROOT/.ci/swift-ci" run tla-models || fail "TLC found a violation, or could not run"
}

case "${1:-all}" in
    lean) run_lean ;;
    tla) run_tla ;;
    all) run_lean; run_tla ;;
    *) fail "usage: model.sh [lean|tla]" 2 ;;
esac
printf '[OK] models hold\n'
