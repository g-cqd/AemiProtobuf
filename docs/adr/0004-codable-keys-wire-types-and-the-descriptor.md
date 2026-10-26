---
status: accepted
date: 2026-10-25
---

# 0004 — Codable needs integer keys; wire types, maps and oneofs need a descriptor

## Context

`Encodable` and `Decodable` were designed for self-describing formats. Protobuf is numbered and typed on the wire.

## Evidence

A recording `Encoder` (`docs/research/probes/codable-shape`) over synthesized conformances shows:

| Question | Answer |
|---|---|
| Key numbers | Synthesized `CodingKeys` give `intValue == nil`. `enum CodingKeys: Int, CodingKey` gives `intValue` (1, 2). |
| Field encodings | `Int32` arrives as `encode(_: Int32, forKey:)`, so `int32`, `sint32`, `sfixed32` and `enum` are indistinguishable. |
| `Data`, `[UInt8]` | Arrive as `encode<T>` with `T == Data` / `[UInt8]`, so the encoder can intercept by type. Unintercepted they become an unkeyed run of single bytes. |
| Maps | `[String: V]` is a keyed container with a private key type; `[Int32: V]` is an unkeyed container alternating key and value. A map is detected by type, not by shape. |
| `Optional` | A `nil` is never reported on the synthesized path, only present values (`encodeIfPresent`). Presence is therefore implicit and free. |
| Enums | A raw-value `Int32` enum arrives as a single-value `Int32`. A Swift enum with payloads (a oneof) arrives as a keyed container with `_0`. |

## Decision

1. The Codable coders require integer `CodingKeys`. A type without them fails with a typed error naming the type, never guesses
   from declaration order (the decoder cannot see order).
2. A type may also supply a static descriptor (hand-written or macro-generated) that names each field's wire encoding
   (`sint32`, `fixed64`, `packed`, map, oneof) and presence. The coders consult it by `intValue`.
3. With no descriptor, scalars use the proto3 defaults for their Swift type: `Int32`/`Int64` as `int32`/`int64`,
   `UInt32`/`UInt64` as `uint32`/`uint64`, `Float`/`Double` as fixed, `Bool`, `String`, `Data`, arrays packed for scalars.
4. Unknown-field preservation, `required`, and oneof exclusivity cannot go through Codable. They exist on the fast path and in the
   descriptor-driven checker only.

## Consequences

`@ProtoMessage` (roadmap 0005) is not an optimization of Codable, as `@JSONCodable` is for JSON. It is the only way to express a
full proto3 message in plain Swift, and Codable is the interoperable subset.
