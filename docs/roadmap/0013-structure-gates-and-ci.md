---
status: in-progress
blocked-by: []
date: 2026-10-25
---

# 0013 — Structure gates and CI

## Done (ADR-0006, ADR-0007)

`Scripts/quality.sh` with the gates format, lint, analyzers, test, model, bench, mutation; `Scripts/tools.lock` and `Scripts/tools.sh`;
the four repository gates ported from `aemiregex` and proved on this repository; swift-format, SwiftLint metrics, deadwood, dolly,
arcleak, fcheck and modeler clean; Lean proofs, a TLA+ model and an exhaustive differential test; mutation testing with a baseline;
allocation-threshold benchmarks; git hooks; a standalone workflow.

CI on macOS (`a53a089`): every job installs the toolchain `.swift-version` names with `swift-actions/setup-swift` pinned by
SHA (the image's 6.3.3 refused tools version 6.4.0), and `quality.sh` finds swift-format on PATH, then through
`xcrun --find`, then as `swift format`. Format/lint/analyzers, tests (debug and release), Lean/TLA+/modeler and the
allocation thresholds are green on the first run with the fix.

## Still open

- **Linux is unverified** (roadmap 0029). CI is green on macOS (run 40959879484, `a53a089`, every job on `macos-26`); no job runs on Linux
  (swift-format there, `-Xswiftc -enable-testing`, the Lean install).
- **No gate bans force unwrap or force try.** The Aemi `Lint` plugin did; this repository does not use it. Add a source scan to
  `AemiProtobufRepositoryTests` in the style of `NoRecursionTests`, broken on purpose first.
- **A fuzz target** in the style of `AemiJSONFuzz` for the reader (libFuzzer builds on Linux only).
- **Coverage gate** and sanitizer runs (`--sanitize=address`, `thread`) in CI.
- **DocC** build check.
