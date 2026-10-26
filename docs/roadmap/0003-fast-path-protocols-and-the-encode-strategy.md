---
status: done
blocked-by: []
date: 2026-10-25
---

# 0003 — Fast-path protocols and the encode strategy

Scope: `AemiProtoFastDecodable` / `AemiProtoFastEncodable` over `WireReader` / `WireWriter`; the `AemiProtobuf` umbrella with `Data` interop.

Probes before the macro commits (ADR-0005): (a) size-first, back-patch and reverse writing on the 1,000-user corpus; (b) inlinable local varint loop against the cross-module kernel call (ADR-0002). Release, medians, allocation counts with `CAemiTestKitMalloc`.

Unknown-field preservation lives here: a `_unknownFields` byte store in the fast path.

## Done (ADR-0008, ADR-0009)

1. Probed nested message encoding: shift back-patching measured 167.4 µs (825 MB/s) vs 180.5 µs (765 MB/s) for pre-sizing. In-place shift is 1.08x faster and visits fields only once.
2. `AemiProtoFastEncodable` and `AemiProtoFastDecodable` protocols implemented.
3. A fast conformance for `Array` of fast elements (a top-level list, repeated field 1). The scalar conformances and `EncoderBufferPool` of the first draft were removed (ADR-0010): a bare scalar is not a message, and the pool was never used.

## Open

- A pooled encode buffer, if a measurement shows allocation of the output array matters (it is one allocation per encode today).
- Unknown-field preservation (`_unknownFields`) is not built.
