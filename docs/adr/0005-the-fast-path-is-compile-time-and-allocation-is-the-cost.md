---
status: accepted
date: 2026-10-25
---

# 0005 — The fast path is compile-time; string and allocation cost, not varints, is what to remove

## Context

AemiJSON's biggest wins come from a monomorphic macro path and from not materializing what is not read. What is the equivalent
here, and where does the time go?

## Evidence

Probe `docs/research/probes/throughput`: 1,000 `User` messages (138,083 bytes, ten fields: varints, strings, a packed repeated
int32, a nested message, sint32, fixed64), swift-protobuf 1.39.0 generated code against a hand-written fast path on the AemiKernel
`Varint`. The two encoders produce identical bytes, and each decodes the other's output to an equal value. Release build; medians of 15; the
machine was busy, absolute numbers moved by up to 2.5x between runs, so only ratios inside one run mean anything.

| Quantity | Result |
|---|---|
| Encode, swift-protobuf / hand path | 1.3 to 1.6x slower, in each of six runs |
| Decode, hand path with `String(validating:)` | parity with swift-protobuf: 0.8 to 1.0x in five runs, 0.6x in the first, cold run |
| Decode, same, UTF-8 validated by the `AemiKernels` SIMD kernel | 1.4 to 1.9x faster than swift-protobuf (one disturbed run showed 3.4x and is not used) |
| Decode, hand path with strings skipped | 2.6x faster than with `String(validating:)` (384 against 986 µs, the one run that measured it); `String(decoding:)` without validation took 481 µs |

String materialization and validation is the largest decode cost. The kernel validator is the cheap win. The varint loop is not
the bottleneck, so a SIMD varint is not a first priority.

Limits of the probe: the hand code does not keep unknown fields, does not check `required`, and one message shape was measured.
It shows headroom, not a product.

## Decision

- The fast-path protocols take the wire core's reader and writer, and the macro (roadmap 0005) emits straight-line code per
  message, as `@JSONCodable` does.
- Decode validates UTF-8 with the kernel, then makes the `String`. A borrowed string view that never makes a `String` is the
  next step (roadmap 0006), and is an open question until probed.
- Encoding nested messages needs the length before the body. The core back-patches in place: a one-byte slot, one shift for bodies of
  128 bytes or more (built, tested at every varint-size boundary). Computing the size first, or writing backwards, may be faster.
  That is open; roadmap 0003 probes all three on this corpus before the macro commits to one.
