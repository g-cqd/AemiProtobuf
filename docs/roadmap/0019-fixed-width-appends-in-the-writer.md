---
status: done
blocked-by: []
date: 2026-10-25
---

# 0019 — Fixed-width and bulk appends in the writer

First run of `docs/research/2026-10-25-aemijson-vs-aemiprotobuf.md` (release): encoding 100,000 doubles took AemiProtobuf 628 µs
and swift-protobuf 16.9 µs for the same bytes; small integers 247 against 164 µs; 20,000 ASCII strings 426 against 226 µs.

## Done

- `appendPackedLittleEndian` / `readPackedLittleEndian` (one copy of the words), `appendPackedVarints` / `readPackedVarints`
  (sizes summed first, element count from a word-at-a-time scan), `readPayload` (a packed run costs no nesting level),
  `WireWriter.reserve(additional:)`, a one-byte fast path in `appendVarint`, and the macro uses them for every packed field whose
  Swift type has the wire type's layout. Same bytes: the protoc oracles, `WireBulkTests`, `WirePackedVarintTests`.
- Doubles encode 628 → 13.0 µs, decode 268 → 27.6 µs; wide integers decode 592 → 341 µs, encode 558 → 523 µs.

## Open

- Integer encode is still 1.3–1.5× slower than swift-protobuf (wide 523 against 396 µs, small 261 against 171 µs), and string
  encode 1.7–1.9× (416 against 223 µs, ASCII).
- Tried and measured, no gain, removed: a fused tag-length-bytes `appendField(string:)`; an exact up-front size (one allocation
  instead of twelve, not faster); `withUTF8` (21 % in an isolated loop, none in place). So the gap is not allocation or call
  count. The remaining hypothesis is the per-append bookkeeping of `Array` (uniqueness check, capacity check, count update) against
  swift-protobuf's pointer writes into a pre-sized buffer.
- Experiment: a writer over a raw buffer it manages (`ManagedBuffer` or an owned allocation), with `bytes` copied out once. It
  touches every write path, so it needs the oracle and mutation gates, and a measurement on `numbers/*` and `strings/*` encode.

Acceptance: the same bytes, allocation thresholds unchanged or lower, mutation gate green, and the comparison's encode rows re-run.

## Done (2026-10-30)

Measured with the harness (0012) before and after, p50, release, the Comparison encode rows:

| workload | before | after | swift-protobuf |
|---|---:|---:|---:|
| 100,000 small integers | 240 µs | 108 µs | 136–161 µs |
| 100,000 wide integers | 455 µs | 315 µs | 321–347 µs |
| 20,000 long strings | 421 µs | 256 µs | 214–221 µs |
| 20,000 ASCII strings | 371 µs | 276–300 µs (p0 239) | 171–177 µs |
| 20,000 multi-byte strings | 381 µs | 278–349 µs (p0 255) | 183–196 µs |

- Packed varints: the body is grown once and written through one buffer, instead of an `append` per byte (whose uniqueness and
  capacity checks were the cost, as the hypothesis said). Integer encode is now ahead of swift-protobuf.
- Repeated strings and bytes: `appendRepeatedStrings` / `appendRepeatedBytes` size every record first, grow once and write tag,
  length and payload through one buffer; the macro uses them for `[String]` and `[[UInt8]]`. Same bytes as one record per element
  (`WireRepeatedPayloadTests`); allocation thresholds unchanged.
- Left: strings are still 1.3–1.6× behind swift-protobuf, and the escaped and multi-byte rows are bimodal (p0 ~270 µs, p50 up
  to 556 µs) with two allocations and CPU time equal to wall time. The likely cause is the zero-fill before the write (every page
  touched twice; swift-protobuf writes into an uninitialized buffer of the exact size), which `Array` cannot avoid without
  unsafe initialization of its tail. A writer over a buffer it owns would; it touches every write path and is not worth the
  risk while message encode is already twice swift-protobuf's speed.
