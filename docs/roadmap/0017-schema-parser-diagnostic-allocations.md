---
status: not-started
blocked-by: [0002]
date: 2026-10-25
---

# 0017 — Schema parser diagnostic allocations

The parser-check refactor introduced measured overhead in `ProtoLexer.expect`, `requireIdentifier`, and `declarationName`.
These helpers construct diagnostic context strings even on successful parsing. The keyword lookup also changed in the same
refactor; the contribution of each change has not been isolated.

Release measurement on the three-field fixture, 10,000 samples per run:

| Version | Mallocs per parse | Wall-clock p50 | Wall-clock p90 |
|---|---:|---:|---:|
| Before shared token checks | 5 | 2,085 ns | 2,333 ns |
| After shared token checks | 19 | 3,625 ns | 3,793 ns |
| After oneof and proto3 `optional` support (a `Frame` per open message, the `oneof` keyword) | 21 | not measured | not measured |

Scope: isolate diagnostic-string construction and keyword classification in the existing schema benchmark. Evaluate lazy
error-context construction without duplicating parser checks or changing failure messages. Preserve malformed-input rejection
and source/depth bounds. Record before/after allocations and timings, and lower the schema allocation threshold only after
measurement. This performance-only regression does not invalidate the correctness repair.
