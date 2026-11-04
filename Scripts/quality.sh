#!/bin/sh
# Every quality gate of the repository, one command each. CI, the git hooks and a developer run the same ones.
#
#   Scripts/quality.sh quality     the quality gate CI runs, from the swift-ci commit CI pins (.ci/swift-ci): swift-format,
#                                  SwiftLint metrics and deadwood, dolly, arcleak, fcheck against .ci/baselines
#   Scripts/quality.sh test        the suite in debug (bounds checks live), then in release (what ships)
#   Scripts/quality.sh model       Lean proofs and TLA+ models under TLC (Scripts/model.sh)
#   Scripts/quality.sh bench       allocation thresholds, then the benchmark report (release)
#   Scripts/quality.sh mutation    swift-mutation-testing on the wire core, with the wire core's tests (about 10 minutes)
#   Scripts/quality.sh fast        quality                   (the pre-commit hook)
#   Scripts/quality.sh docs        DocC for every public module, warnings as errors (Scripts/docs.sh)
#   Scripts/quality.sh coverage    line coverage per module against Scripts/coverage.floor
#   Scripts/quality.sh sanitizers  the suite under AddressSanitizer, then ThreadSanitizer
#   Scripts/quality.sh all         fast, docs, test, model, bench  (the pre-push hook; mutation runs on its own schedule)
#
# Exit: 0 every gate held, 1 a gate failed, 2 a tool is missing or could not run.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

fail() { printf '[FAIL] %s\n' "$1" >&2; exit "${2:-1}"; }

# Formatting, SwiftLint and the analyzers are swift-ci's quality check, with .ci/action.json's scope and the tool lock
# CI uses, so a hook and CI cannot disagree about a finding.
gate_quality() {
    printf '==> .ci/swift-ci run quality\n'
    .ci/swift-ci run quality || fail "quality (formatting, SwiftLint or an analyzer): see above"
}

gate_test() {
    printf '==> swift test (debug)\n'
    swift test || fail "tests failed in debug"
    printf '==> swift test -c release\n'
    # Release is what ships and what the optimizer can break; `@testable` needs testing stated explicitly there.
    swift test -c release -Xswiftc -enable-testing || fail "tests failed in release"
}

gate_bench() {
    printf '==> benchmark: allocation thresholds\n'
    AEMIPROTOBUF_DEV=1 AEMIPROTOBUF_BENCH_GATE=1 swift package benchmark thresholds check --path Benchmarks/Thresholds \
        || fail "an allocation count moved; if it is intended, run  AEMIPROTOBUF_DEV=1 AEMIPROTOBUF_BENCH_GATE=1 swift package --allow-writing-to-package-directory benchmark thresholds update --path Benchmarks/Thresholds  and explain it in the commit"
    printf '==> benchmark: report (wall clock is reported, never gated)\n'
    AEMIPROTOBUF_DEV=1 swift package benchmark || fail "the benchmark run failed"
}

gate_mutation() {
    Scripts/tools.sh install mutation || exit 2
    bin=$(Scripts/tools.sh path mutation) || exit 2
    printf '==> swift-mutation-testing (experimental tier)\n'
    # The gate: no survivor that the committed baseline does not already accept, and a score floor. The baseline holds mutants
    # that cannot change behaviour (each is explained in docs/adr/0007).
    "$bin" run . --sources-path Sources/AemiProtobufCore --no-cache --operator-tier experimental \
        --baseline .swift-mutation-testing-baseline.json --max-new-survivors 0 --min-score 90 \
        || fail "mutation gate: a mutant survived that the baseline does not accept, or the score is under 90"
}

case "${1:-}" in
    quality | format | lint | analyzers) gate_quality ;;
    test) gate_test ;;
    model) Scripts/model.sh all ;;
    bench) gate_bench ;;
    mutation) gate_mutation ;;
    docs) Scripts/docs.sh || fail "documentation" ;;
    coverage) Scripts/coverage.sh || fail "a module's line coverage fell under its floor (Scripts/coverage.floor)" ;;
    sanitizers)
        # The depth-limit test recurses through Codable 100 levels, which ASan's larger frames do not fit in a test thread's
        # 512 KB; the limit it checks holds in the builds that ship (it passes in debug and release).
        swift test --sanitize=address --skip 'deeply nested input is refused at the limit' || fail "AddressSanitizer"
        swift test --sanitize=thread || fail "ThreadSanitizer" ;;
    fast) gate_quality ;;
    all) gate_quality; Scripts/docs.sh || fail "documentation"; gate_test; Scripts/model.sh all; gate_bench ;;
    *) fail "usage: quality.sh quality|docs|coverage|sanitizers|test|model|bench|mutation|fast|all" 2 ;;
esac
printf '[OK] %s\n' "$1"
