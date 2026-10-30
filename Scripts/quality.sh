#!/bin/sh
# Every quality gate of the repository, one command each. CI, the git hooks and a developer run the same ones.
#
#   Scripts/quality.sh format      swift-format lint --strict over Sources, Tests, Benchmarks and Package.swift
#   Scripts/quality.sh lint        SwiftLint metrics (.swiftlint.yml), --strict
#   Scripts/quality.sh analyzers   deadwood, dolly, arcleak, fcheck (--strict) and `modeler check`
#   Scripts/quality.sh test        the suite in debug (bounds checks live), then in release (what ships)
#   Scripts/quality.sh model       Lean proofs, TLA+ models under TLC, modeler (Scripts/model.sh)
#   Scripts/quality.sh bench       allocation thresholds, then the benchmark report (release)
#   Scripts/quality.sh mutation    swift-mutation-testing on the wire core, with the wire core's tests (about 10 minutes)
#   Scripts/quality.sh fast        format, lint, analyzers   (the pre-commit hook)
#   Scripts/quality.sh docs        DocC for every public module, warnings as errors (Scripts/docs.sh)
#   Scripts/quality.sh coverage    line coverage per module against Scripts/coverage.floor
#   Scripts/quality.sh sanitizers  the suite under AddressSanitizer, then ThreadSanitizer
#   Scripts/quality.sh all         fast, docs, test, model, bench  (the pre-push hook and CI; mutation runs on its own schedule)
#
# Exit: 0 every gate held, 1 a gate failed, 2 a tool is missing or could not run.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

fail() { printf '[FAIL] %s\n' "$1" >&2; exit "${2:-1}"; }

# What the analyzers read: the whole package, because reachability and clone detection are whole-program. Benchmarks/ is left out:
# the Benchmark plugin finds its entry point by name, which no syntax-level analyzer can see, so every benchmark looks dead.
CORPUS="Sources Tests"
SWIFT_FILES="Sources Tests Benchmarks Conformance Package.swift"

# The toolchain's own swift-format: on PATH from a toolchain install, otherwise Xcode's, otherwise the `swift format` subcommand.
swift_format() {
    if command -v swift-format >/dev/null 2>&1; then
        swift-format "$@"
    elif found=$(xcrun --find swift-format 2>/dev/null); then
        "$found" "$@"
    else
        swift format "$@"
    fi
}

gate_format() {
    printf '==> swift-format lint --strict\n'
    # shellcheck disable=SC2086
    swift_format lint --strict -r $SWIFT_FILES || fail "formatting: run  swift-format format -i -r $SWIFT_FILES"
}

gate_lint() {
    command -v swiftlint >/dev/null 2>&1 || fail "swiftlint is not installed (brew install swiftlint)" 2
    printf '==> swiftlint --strict\n'
    swiftlint lint --strict --quiet --config .swiftlint.yml || fail "SwiftLint metrics"
}

gate_analyzers() {
    Scripts/tools.sh install deadwood dolly arcleak fcheck modeler || exit 2
    failed=0
    for tool in deadwood dolly arcleak fcheck; do
        bin=$(Scripts/tools.sh path "$tool") || exit 2
        printf '==> %s\n' "$tool"
        baseline=""
        [ "$tool" = dolly ] && [ -f .dolly-baseline.json ] && baseline="--baseline .dolly-baseline.json"
        # --strict: a warning fails, a note never does. Each tool reads its own .<tool>.json. Accept a finding where it is, with a
        # directive and a reason (`// @dl:accept -- why`, `// @fc:accept rule -- why`), never silently.
        # shellcheck disable=SC2086
        "$bin" analyze --strict --no-cache --relative-to . $baseline $CORPUS || failed=1
    done
    [ "$failed" -eq 0 ] || fail "a static analyzer reported findings"
    printf '[OK] analyzers clean\n'
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
    format) gate_format ;;
    lint) gate_lint ;;
    analyzers) gate_analyzers ;;
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
    fast) gate_format; gate_lint; gate_analyzers ;;
    all) gate_format; gate_lint; gate_analyzers; Scripts/docs.sh || fail "documentation"; gate_test; Scripts/model.sh all; gate_bench ;;
    *) fail "usage: quality.sh format|lint|analyzers|docs|coverage|sanitizers|test|model|bench|mutation|fast|all" 2 ;;
esac
printf '[OK] %s\n' "$1"
