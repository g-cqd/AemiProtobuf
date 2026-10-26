---
status: in-progress
blocked-by: []
date: 2026-10-25
---

# 0005 — ProtoMessage macro

Scope: `@ProtoMessage`, `@ProtoField(n, encoding)`, `@ProtoOneof` over a struct; generates the fast-path conformances, the descriptor, and `protoDefinition` text. Follows AemiJSON's macro layout (`AemiJSONMacros`, `AemiMacroSupport`). Types it cannot handle fall back to Codable with a diagnostic, as `@JSONCodable` does. Duplicate or reserved numbers are compile errors.

## Done (ADR-0011)

1. `@ProtoMessage` and `@ProtoField(number, kind)` (`AemiProtobufMacros`, re-exported through `AemiProtobuf`): the fast path
   (`AemiProtoFastEncodable`, `AemiProtoFastDecodable`) and `Codable` with integer `CodingKeys`, for every kind: `int32`, `int64`,
   `uint32`, `uint64`, `sint32`, `sint64`, `fixed32`, `fixed64`, `sfixed32`, `sfixed64`, `bool`, `float`, `double`, `string`,
   `bytes`, enumerations and nested messages, as single, optional and repeated (packed or one record per element) fields.
2. Oracle: `kinds.proto` / `kinds.bin` from `protoc --encode`; the generated code writes those bytes and reads them back, and the
   generated `Codable` round-trips. The comparison package's records are macro types and write the same bytes as swift-protobuf.
3. Diagnostics, each with a test: no `@ProtoField`, no default, a map, a kind that does not fit the type, a repeated number, a
   number out of range or reserved, a non-literal number, a class, an array of optionals or an optional array.

## Open

- `@ProtoOneof` and maps. The descriptor and `protoDefinition` text the original scope names.
- Unknown-field preservation, and merging a repeated nested message given twice (the last occurrence wins today).
- A fallback to `Codable` with a note, where AemiJSON's macro degrades instead of refusing: this macro refuses, because a
  silently slower message is a worse failure than a compile error.
- Mutation coverage of the macro target.
