---
status: superseded
superseded-by: ADR-0010
date: 2026-10-25
---

# 0009 — Fast-path protocols and Codable architecture in `AemiProtobuf`

## Context

Following `AemiJSON`, high performance API communication requires:
1. Direct, monomorphic encoding and decoding skipping `Encoder` / `Decoder` container existential boxing.
2. Interoperability with standard Swift `Codable` structs without requiring external generators.

## Decision

1. **Protocols**:
   `AemiProtoFastEncodable` (`func __aepbEncode(into writer: inout WireWriter) throws(WireError)`)
   `AemiProtoFastDecodable` (`static func __aepbDecode(from reader: inout WireReader) throws(WireError)`)
   Built-in conformances are provided for standard Swift types (`Int`, `Int32`, `Int64`, `UInt32`, `UInt64`, `Double`, `Float`, `Bool`, `String`, `[UInt8]`, `Data`, `Optional`, `Array`).

2. **Codable Coders**:
   `ProtobufEncoder` and `ProtobufDecoder` live in the umbrella target `AemiProtobuf`.
   They mirror `AemiJSON.JSONEncoder` / `AemiJSON.JSONDecoder`:
   - Inspect if the root type conforms to `AemiProtoFastEncodable` / `AemiProtoFastDecodable` and take the monomorphic fast path directly.
   - For generic `Codable`, decode/encode through standard `KeyedDecodingContainer` / `KeyedEncodingContainer` using integer `CodingKeys` (per ADR-0004).
   - Unknown fields can be skipped automatically or preserved.
   - Buffer pooling: `ProtobufEncoder` recycles byte buffers using `AemiKernel.ByteBufferPool` (like `AemiJSON`'s `EncoderBufferPool`).

3. **Field numbers**:
   In Swift `Codable`, `CodingKeys` must conform to `CodingKey` with non-nil `intValue`.
