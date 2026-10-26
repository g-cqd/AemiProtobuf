---
status: done
blocked-by: []
date: 2026-10-25
---

# 0004 — Codable encoder and decoder

Scope: `ProtobufEncoder` / `ProtobufDecoder` per ADR-0004: integer `CodingKeys`, interception of `Data`, `[UInt8]`, maps and raw-value enums by type, proto3 implicit presence (`decode` of an absent field gives the default, `decodeIfPresent` gives nil), packed arrays, nested messages with the depth limit, `userInfo`. A descriptor, when the type supplies one, selects `sint`, `fixed`, maps and oneof.

Tests attack: absent keys, duplicate fields (last wins for scalars, merge for messages), unknown fields, wrong wire type, recursion bomb, 2^31 length. Differential against `protoc --encode` and `--decode`.

## Done (ADR-0010, replacing the prototype of ADR-0009)

1. `ProtobufEncoder` and `ProtobufDecoder`: keyed (message), unkeyed (repeated, packed numbers) and single-value (scalar, enum)
   containers over a shared writer and a per-message field index. Integer `CodingKeys` are validated; none traps.
2. Proto3 presence: `encode` omits defaults, `encodeIfPresent` writes set values, `decodeIfPresent` is `nil` when absent, an
   absent non-optional field is its default.
3. Oracle: `protoc --encode` bytes for a 12-field message are written byte for byte by the encoder and read back by the decoder
   (`CodableOracleTests`). The comparison package round-trips 20,000 nested records through it and checks its bytes equal the
   fast path's.
4. Adversarial tests: merge, last-wins, unknown fields, packed/unpacked mix, wire-type mismatch, range overflow, bad UTF-8,
   truncation, 3,000 random buffers, depth limit both ways, oversized message, dictionaries, top-level scalar and array.

## Open

- A descriptor-driven mode for `sint`, `fixed`, `map`, `oneof` and unknown-field preservation.
- Mutation coverage of the umbrella target; the mutation gate still runs the wire core only.
- The generic path's cost (see the comparison): it builds an index per message and a child encoder per field value.
