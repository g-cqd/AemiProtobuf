#!/bin/sh
# AemiJSON against AemiProtobuf on the same logical data (Benchmarks/Comparison).
#
#   Scripts/compare.sh check    round-trip every codec, print encoded sizes, and have protoc decode the protobuf bytes
#   Scripts/compare.sh bench    the full benchmark run (about 10 minutes, release); raw text to $OUT/raw.txt
#   Scripts/compare.sh memory   peak and retained memory of one 20,000-record decode per codec, one process each
#   Scripts/compare.sh report   turn $OUT/raw.txt into $OUT/report.md
#   Scripts/compare.sh all      check, bench, report
#
# OUT defaults to Benchmarks/Comparison/results (untracked). Run on a quiet machine: the numbers are wall clock.
# Needs the AemiJSON checkout next to this one (override with AEMIJSON_PATH) and, for the protoc check, protoc.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIR="$ROOT/Benchmarks/Comparison"
OUT=${OUT:-"$DIR/results"}
mkdir -p "$OUT"

fail() { printf '[FAIL] %s\n' "$1" >&2; exit "${2:-1}"; }

do_check() {
    printf '==> round trip of every codec, and encoded sizes\n'
    # Not piped into tee: a pipe would hide the exit status of the check.
    (cd "$DIR" && swift run ComparisonSizes --write "$OUT") >"$OUT/sizes.md" || fail "a codec failed its round trip"
    cat "$OUT/sizes.md"
    if command -v protoc >/dev/null 2>&1; then
        printf '==> protoc --decode of the protobuf bytes\n'
        (cd "$DIR" && protoc --decode=Users comparison.proto <"$OUT/users-n100.bin" >"$OUT/users-n100.txt") \
            || fail "protoc refused the protobuf bytes"
        count=$(grep -c '^users {' "$OUT/users-n100.txt" || true)
        [ "$count" -eq 100 ] || fail "protoc decoded $count users, expected 100"
        printf 'protoc decoded %s users\n' "$count"
    else
        printf 'protoc is not installed: the independent decode check was skipped\n'
    fi
}

do_bench() {
    printf '==> benchmark (release, wall clock; leave the machine alone)\n'
    (cd "$DIR" && swift package benchmark --no-progress --time-units nanoseconds) >"$OUT/raw.txt" \
        || fail "the benchmark run failed"
}

do_memory() {
    printf '==> memory: one decode of 20,000 records per process\n'
    (cd "$DIR" && swift build -c release --product ComparisonMemory >/dev/null) || fail "could not build ComparisonMemory"
    bin="$DIR/.build/release/ComparisonMemory"
    "$bin" prepare "$OUT" || fail "could not prepare the memory inputs"
    printf 'codec\tpeak growth (MB)\tretained (MB)\n' >"$OUT/memory.tsv"
    for codec in json.AemiJSON.codable json.AemiJSON.macro json.AemiJSON.tape json.Foundation json.Foundation.JSONSerialization \
        pb.AemiProtobuf.fast pb.AemiProtobuf.codable pb.SwiftProtobuf; do
        "$bin" run "$OUT" "$codec" | awk -F'\t' '{printf "%s\t%.1f\t%.1f\n", $1, $2/1048576, $3/1048576}' >>"$OUT/memory.tsv" \
            || fail "$codec failed"
    done
    cat "$OUT/memory.tsv"
}

do_report() {
    [ -f "$OUT/raw.txt" ] || fail "no $OUT/raw.txt: run  Scripts/compare.sh bench" 2
    python3 "$DIR/report.py" "$OUT/raw.txt" >"$OUT/report.md"
    printf 'wrote %s\n' "$OUT/report.md"
}

case "${1:-}" in
    check) do_check ;;
    bench) do_bench ;;
    memory) do_memory ;;
    report) do_report ;;
    all) do_check; do_bench; do_memory; do_report ;;
    *) fail "usage: compare.sh check|bench|memory|report|all" 2 ;;
esac
