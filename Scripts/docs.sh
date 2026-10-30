#!/bin/sh
# DocC check (roadmap 0013): every public module's documentation builds with no warning, so a ``Symbol`` link that names nothing,
# or a parameter that no longer exists, fails the gate.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
swift package dump-symbol-graph --minimum-access-level public >/dev/null
GRAPHS="$ROOT/.build/out/symbolgraph"
[ -d "$GRAPHS" ] || GRAPHS=$(find "$ROOT/.build/" -maxdepth 4 -type d -name symbolgraph | head -n 1)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
failed=0
for module in AemiProtobufCore AemiProtobuf AemiProtobufSchema AemiProtobufGenerator; do
    mkdir -p "$WORK/$module"
    find "$GRAPHS" -name "$module.symbols.json" -o -name "$module@*.symbols.json" | while read -r graph; do
        cp "$graph" "$WORK/$module/"
    done
    if ! xcrun docc convert --additional-symbol-graph-dir "$WORK/$module" --fallback-display-name "$module" \
        --fallback-bundle-identifier "org.aemi.$module" --output-path "$WORK/$module.doccarchive" \
        --warnings-as-errors >"$WORK/$module.log" 2>&1; then
        printf '[FAIL] %s documentation:\n' "$module" >&2
        grep -E 'warning:|error:' "$WORK/$module.log" >&2 || cat "$WORK/$module.log" >&2
        failed=1
    fi
done
exit "$failed"
