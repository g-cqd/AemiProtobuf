---
status: done
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

## Done since (2026-10-30)

- `@ProtoOneof` (0026), maps (0025), unknown fields (0022, ADR-0012) and merging (0020) are in, each with its own entry.
- The definition: `@ProtoMessage` conforms the type to `AemiProtoDefined`, writing `protoName`, `protoDefinition` and
  `protoDependencies`; `@ProtoOneof` writes its members' lines. The definition is in edition 2023, which states exactly what
  the macro means:
  - implicit presence for a plain field, explicit for an `Optional`;
  - `LEGACY_REQUIRED`, delimited groups, `repeated_field_encoding = EXPANDED` for `packed: false`;
  - maps as `map<K, V>`, oneofs as blocks.

  An integer enumeration that is `CaseIterable` gets its definition by conforming. Its values are named `TYPE_CASE`, and it
  is closed unless `init(rawValue:)` accepts a number with no case. `ProtoDefinitions.file(for:package:)` gathers a type and
  everything it reaches into one file, iteratively, and names a type with no definition.
- Oracle (`ProtoDefinitionTests`): every-kind, oneof, map, group and required test types. Each file compiles with
  `ProtoCompiler`, and a dynamic message of the compiled descriptor reads the macro's bytes and writes bytes the macro reads
  back to the same value.
- The `Codable` fallback is decided against. The macro refuses what it cannot write, because a silently slower message is a
  worse failure than a compile error.

## Open

- Mutation coverage of the macro target (deferred with the CI work, 0013).
- Definitions name types by their own name, so two nested types of one name collide (`duplicateName`).
