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

- Linux: done in roadmap 0029 (tests in debug and release).
- **No gate bans force unwrap or force try.** The Aemi `Lint` plugin did; this repository does not use it. Add a source scan to
  `AemiProtobufRepositoryTests` in the style of `NoRecursionTests`, broken on purpose first.
- **A fuzz target** in the style of `AemiJSONFuzz` for the reader (libFuzzer builds on Linux only).
- **Coverage gate** and sanitizer runs (`--sanitize=address`, `thread`) in CI.
- **DocC** build check.

## Done (2026-10-30)

- No force: `NoForceUnwrapTests` scans the library for `x!`, `as!`, `try!` and `T!` after comments and strings are blanked; its
  fixtures find every kind and nothing in `!=`, negation, strings or comments. The library has none.
- DocC: `Scripts/docs.sh` (`quality.sh docs`, CI's static job) builds every public module's documentation with warnings as errors.
  It found two broken links, now fixed.
- Coverage: `Scripts/coverage.sh` (`quality.sh coverage`, CI's test job), line coverage per module over every test bundle, against
  floors in `Scripts/coverage.floor` set just under the measured run: Core 97.6 %, Schema 92.2 %, Generator 80.5 %, AemiProtobuf
  67.3 %, Macros 62.9 % (the macros' expansion tests only; expansion in the compiler is not counted).
- Sanitizers: `quality.sh sanitizers` (a CI job) runs the suite under ASan and TSan; both clean locally. The depth-limit test is
  skipped under ASan, whose frames do not fit 100 `Codable` levels in a test thread's 512 KB; it passes in debug and release.
- Fuzz: `Sources/AemiProtobufFuzz`, gated by `AEMIPROTOBUF_FUZZ` as AemiJSON's is (libFuzzer is Linux-only): the wire core, the
  macro path (maps, oneof, groups, required, recursion) with a decode-encode-decode check, the generic path, descriptors and the
  validator, framing. Not yet run: the Linux container run was stopped; running it and a CI fuzz job are deferred with the rest of the
  CI work.

## Open

- Run the fuzz target and add a CI job for it.
- CI has not been checked since these jobs were added (deferred by the owner, 2026-10-30).
