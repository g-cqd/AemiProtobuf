---
status: not-started
blocked-by: [0023, 0028]
date: 2026-10-25
---

# 0011 — Conformance and oracles

Scope: build the official `conformance_test_runner` from the protobuf source (the Homebrew `protoc` 36.2 does not ship it; open question 5), drive it from a Swift testee, and record the failure list. Add a generated differential (seeded message generator, `protoc --encode` as oracle) to the existing mutation corpus.

Order (research 2026-10-29-conformance-review): the macro's correctness first (0020–0023), then what the conformance messages need
(0024–0027), the generator (0028), then this. Build the runner from protobuf v36.2 (the `protoc` here) with CMake against the
installed abseil; a testee executable in a dev-only package, as `Benchmarks/Comparison`; JSON requests answered "skipped" until
0010. Acceptance: the runner's binary tests pass for proto3 and proto2, each remaining failure in a committed failure list with a
reason, and the run in CI or, if the runner build is too slow for it, a script and the recorded result.
