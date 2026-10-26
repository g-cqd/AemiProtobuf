---
status: accepted
date: 2026-10-25
---

# 0007 — Models, mutation testing and benchmarks: what each is for, and what it is not

## Context

Tests show that the cases someone thought of pass. Three further tools ask different questions, and each one can overclaim.

## Decision

**Lean 4 (`Models/lean`)** proves facts about the format for every input, over the mathematical definition. Proved: zig-zag is a
bijection on 32 and 64 bits (`bv_decide`); a value in -64..63 encodes to one byte; the varint encoding decodes back to its value for
every natural number; its length is what `width` says; every byte is below 256; a value below 2^64 takes at most ten bytes.
Not proved: that the Swift code implements the definition. The tie is a test (`the varint width formula matches the kernel encoder at
every bit boundary`) and the differential and exhaustive tests. `lake build --wfail` and a `sorry` ban.

**TLA+ with TLC (`Models/tla`)** checks an algorithm over every input up to a bound. `GroupSkip` is the group-skipping loop: 389,712
states, the open-group stack never passes the depth limit, every run ends, and the loop accepts exactly what an independent,
stack-free definition accepts. The same definition is the oracle of a Swift test that runs the real reader over every token
sequence of up to six tokens (about 156,000 inputs) and found no disagreement: the model checks the design, the test checks the code.

**modeler** generates a TLA+ model from Swift source for a type that has an `await` or takes a lock, and `modeler check` reports a
check, a suspension point, then a write with no new check. The wire core has none of these, so it reports nothing and the gate is
a tripwire for the pool and streaming types of roadmap 0003 and 0009. When it reports, `modeler tla --type T` plus TLC gives a
trace (verified on a planted actor: TLC reported `NoStaleWrite_1`).

**swift-mutation-testing** asks whether the tests can fail. Default tier: 24 mutants, 24 killed. Experimental tier: 99 mutants,
88 killed on the first run, 7 survived, 4 did not compile. Every survivor was read: four were real gaps and are now tested
(`appendBytes` with a non-empty payload; a buffer exactly at the size limit, on the reader and the writer; the tag 0xFFFFFFFF; the
order of `FieldNumber`), one is a performance-only mutant (`reserveCapacity`) that the allocation threshold kills, and the rest are
in `.swift-mutation-testing-baseline.json` with the reason. The gate is: no survivor the baseline does not hold, score at least 90.
Run weekly and on demand, not per push: about nine minutes.

**Benchmarks** (`Benchmarks/AemiProtobufSuite`, dev-gated by `AEMIPROTOBUF_DEV`) measure the 1,000-user corpus of the throughput
probe, varint read and write, and group skipping. The gate is the allocation count, which is exact and has a strict threshold file
(`Benchmarks/Thresholds`). The wall clock is reported and never gated: a median moved between 220 and 297 µs across two runs here. A
speed claim still needs the frozen comparison of roadmap 0012; these numbers are a baseline for this machine.

## Baseline (this machine, release, p50)

| Benchmark | Wall clock | Mallocs |
|---|---|---|
| Users1000.write | 297 µs | 1 |
| Users1000.read (every field, strings made) | 380 µs | 1,000 |
| Varint4096.write | 23 µs | 1 |
| Varint4096.read | 21 µs | 0 |
| Group3Deep1000.skip | 125 µs | 1,010 |

Findings: writing the whole message, nested messages included, takes one allocation, so the in-place length back-patch costs no
scratch buffer. The probe's hand-written encoder, which called the kernel `Varint` directly, measured 250 to 640 µs on the same
corpus across runs, so the module boundary (ADR-0002) shows no cost on this evidence; it is not a controlled comparison.
`skipField` allocates once per group (the open-group array): a performance-only finding, queued as roadmap 0016.

## Consequences

Four gates cost time: mutation (nine minutes), TLC (fourteen seconds), Lean (a few seconds), benchmarks (about two minutes). Only
mutation is kept off the per-push path. A new feature adds its own model, proof or oracle test when it has an algorithm, and its
own benchmark when it has a hot path.
