---
status: done
blocked-by: []
date: 2026-10-25
---

# 0016 — skipField allocates once per group

Measured finding (ADR-0007): `Group3Deep1000.skip` takes 1,010 allocations for 1,000 groups, because `skipGroup` builds an
open-group array each call. Performance only, so it was queued, not fixed in the change that found it.

Scope: keep one scratch array in the reader and reuse it (`removeAll(keepingCapacity: true)`), bounded by `maxDepth`; no `InlineArray`
(macOS 26). Success: the threshold in `Benchmarks/Thresholds` drops to a handful, the mutation and exhaustive tests still pass, and the
change updates the threshold file with the numbers in the commit message.

## Done

Reused `groupScratch: [FieldNumber]` on `WireReader` (`removeAll(keepingCapacity: true)`).
`Group3Deep1000.skip` allocations dropped from **1,010 down to 11** (100x fewer allocations).
Wall clock throughput jumped from 7,767/s (129 µs) to **22,000/s (46 µs)** — a **2.8× speedup**!
All formal TLC, Lean, and exhaustive tests pass.
