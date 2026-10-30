#!/bin/sh
# Line coverage of the library (roadmap 0013): the suite with coverage, every test bundle, the library's own files only. Fails
# under MINIMUM percent for any module (Scripts/coverage.floor holds the floors, set from a measured run).
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
swift test --enable-code-coverage >/dev/null
PRODUCTS=$(dirname "$(dirname "$(swift test --show-codecov-path)")")
set --
for bundle in "$PRODUCTS"/*.xctest; do
    name=$(basename "$bundle" .xctest)
    if [ -f "$bundle/Contents/MacOS/$name" ]; then set -- "$@" -object "$bundle/Contents/MacOS/$name"; else set -- "$@" -object "$bundle"; fi
done
xcrun llvm-cov export -summary-only -instr-profile "$PRODUCTS/codecov/default.profdata" "$@" >"$PRODUCTS/codecov/all.json"
python3 - "$PRODUCTS/codecov/all.json" "$ROOT" "$ROOT/Scripts/coverage.floor" <<'PY'
import json, sys, collections
data, root, floors = json.load(open(sys.argv[1])), sys.argv[2], sys.argv[3]
per = collections.defaultdict(lambda: [0, 0])
for f in data["data"][0]["files"]:
    name = f["filename"]
    if not name.startswith(root + "/Sources/"):
        continue
    module = name[len(root) + 9:].split("/")[0]
    lines = f["summary"]["lines"]
    per[module][0] += lines["covered"]
    per[module][1] += lines["count"]
floor = {}
for line in open(floors):
    if line.strip() and not line.startswith("#"):
        module, value = line.split()
        floor[module] = float(value)
failed = False
for module, (covered, count) in sorted(per.items()):
    percent = 100 * covered / max(count, 1)
    want = floor.get(module, 0)
    mark = "ok" if percent >= want else "BELOW"
    failed |= percent < want
    print(f"{module:24s} {covered:6d}/{count:6d} {percent:5.1f}%  floor {want:5.1f}  {mark}")
sys.exit(1 if failed else 0)
PY
