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

## Still open

- **Linux and CI are unverified.** Nothing has run on a runner. Expect the first run to need changes (SwiftLint and Lean install,
  swift-format on Linux, `-Xswiftc -enable-testing`).
- **No gate bans force unwrap or force try.** The Aemi `Lint` plugin did; this repository does not use it. Add a source scan to
  `AemiProtobufRepositoryTests` in the style of `NoRecursionTests`, broken on purpose first.
- **A fuzz target** in the style of `AemiJSONFuzz` for the reader (libFuzzer builds on Linux only).
- **Coverage gate** and sanitizer runs (`--sanitize=address`, `thread`) in CI.
- **DocC** build check.
