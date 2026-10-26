---
status: accepted
date: 2026-10-25
---

# 0008 — In-place shift back-patching is faster than pre-sizing nested messages

## Context

Protobuf length-delimited fields require the length in bytes before the body. When encoding a nested message in Swift, there are three
obvious approaches:
1. In-place shift back-patching: reserve 1 byte for length, write body, then shift body right if length >= 128 bytes.
2. Pre-sizing: calculate message byte length in a first pass, write length varint, then write body in a second pass.
3. Nested scratch buffer: allocate or borrow an auxiliary buffer for the body, measure its count, then write tag + length + bytes.

## Evidence

Probe `docs/research/probes/strategy-probe`: 1,000 `User` messages (138,125 bytes) tested in release mode (`-O -swift-version 6`).
Both strategies produced identical serialized bytes verified by assertion. Median of 15 runs over 300 iterations:

| Strategy | Wall clock time (1,000 users) | Throughput |
|---|---|---|
| In-place shift back-patch | 167.4 µs | 825 MB/s |
| Pre-size pass (two-pass) | 180.5 µs | 765 MB/s |

In-place shift is **1.08× faster** and requires only 1 allocation total (reserving capacity for the output buffer), whereas
pre-sizing visits every field, string UTF-8 count, and array length twice.

## Decision

`WireWriter.appendMessage(field:_:)` retains the in-place shift back-patch algorithm. Both `ProtobufEncoder` and the upcoming
`@ProtoMessage` macro fast paths will generate single-pass shift-based encoding rather than two-pass sizing.

## Note (2026-10-26): what the evidence covers

The probe compared two strategies, in-place shift and pre-sizing, on one corpus. The third (a nested scratch buffer) and writing the
message in reverse were not measured, so this record does not rank them. Packed numeric runs no longer use the shift at all: the core
sums their sizes first (`appendPackedVarints`) or knows them from the count (`appendPackedLittleEndian`), and the comparison's
`numbers/*` rows measure that. Nested messages still use the shift.
