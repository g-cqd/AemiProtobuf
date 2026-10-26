---
status: in-progress
blocked-by: []
date: 2026-10-25
---

# 0002 — Descriptors and the proto parser

Scope: `FileDescriptor` / `MessageDescriptor` / `FieldDescriptor` / `EnumDescriptor` / `OneofDescriptor`; read and write `FileDescriptorSet` using the wire core; a `.proto` lexer and parser (proto3 first, then proto2, then editions) and printer, with no recursion (explicit stack, nesting limit); name resolution and the checks `protoc` makes.

Oracle: `protoc --descriptor_set_out` for every fixture; the parsed descriptor must equal `protoc`'s after a round trip. The Google well-known types and `descriptor.proto` itself are the first corpus.

Probe first: how much of editions do consumers need (open question 6).

## Implemented subset

1. `AemiProtobufSchema` module created with core descriptor types: `FileDescriptor`, `MessageDescriptor`, `FieldDescriptor`, `EnumDescriptor`, `EnumValueDescriptor`, `FileDescriptorSet`.
2. Binary wire serialization (`+Wire.swift`) encoding and decoding `FileDescriptorSet` using `WireReader` and `WireWriter`.
3. Validated differentially against `protoc 36.2 --descriptor_set_out` on `sample.proto`.
4. Pure Swift, non-recursive, stack-based `ProtoParser` and `ProtoLexer` implemented.
5. Round-trip tests in `AemiProtobufSchemaTests` cover one simple fixture, not the complete descriptor schema.
6. `oneof` and proto3 `optional` (synthetic `_name` oneofs after the declared ones), `OneofDescriptor`, `oneof_index` and `proto3_optional` on the wire, protoc's camel-case `json_name`. Oracle: `oneof.proto` parses to exactly the descriptor `protoc` wrote, and re-encodes to the same bytes. An out-of-range `oneof_index` is refused (`DescriptorError`).
7. Lexer rejects unsupported characters, unterminated comments/strings, and overflowing integers. Parser bounds source bytes and nesting, and rejects invalid field numbers.

## Remaining acceptance criteria

- Maps, imports, options, reserved declarations, proto2 and editions semantics, and a printer.
- Name resolution and schema validity checks, including duplicate declarations.
- Complete descriptor-set representation and preservation of unsupported fields/options.
- Differential corpus covering well-known types and `descriptor.proto`.
- Schema parser/descriptor benchmarks and mutation coverage.
