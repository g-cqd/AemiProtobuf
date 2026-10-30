---
status: done
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

8. The descriptor model holds everything protoc writes (2026-10-29): dependencies (public and weak), services and methods,
   top-level and nested extensions (`extendee`), extension and reserved ranges and names, default values, raw options messages,
   `SourceCodeInfo`, `edition`, and unknown fields on every descriptor. Options the generator needs read back on demand (`packed`,
   `map_entry`, `message_set_wire_format`, `allow_alias`, `FeatureSet` at file, message, field and enumeration level). An absent
   `syntax` stays empty (protoc writes none for proto2; `resolvedSyntax` says proto2), so the round trip is exact. Oracle:
   `conformance-set.pb` (protoc `--include_imports` over the conformance, proto2, proto3 and editions test messages and
   `descriptor.proto`, 14 files) decodes and re-encodes byte for byte.

## Done (2026-10-30): the compiler and the printer

9. `ProtoCompiler` compiles `.proto` files as protoc does. Files are read through a loader, and their imports are ordered
   depth first, as `--include_imports` orders them; import cycles are refused. It handles:
   - proto2, proto3 and editions 2023 / 2024 (features as options);
   - maps (`NameEntry` messages), groups, oneofs and synthetic oneofs, extensions and `extend` blocks, extension ranges (a
     message set's `max`), reserved ranges and names;
   - services with streaming; `json_name`;
   - `default` values written as protoc writes them: `%.15g` / `%.6g` from the exact decimal expansion, bytes C-escaped;
   - name resolution by protoc's rule: the first component outward, the rest under it.

   Options are interpreted as `DynamicMessage`s of the option types, against the embedded `descriptor.proto`
   (`Scripts/generate-descriptor-proto.sh`). That covers custom options as extensions, dotted paths into sub-messages, and
   message literals in text format (`ProtoTextParser`). Fields declared `retention = RETENTION_SOURCE` are dropped, as protoc
   drops them, and an rpc with a `{}` body gets empty options.
10. Parsing is iterative, with an explicit scope stack; every later pass loops over a flat model (`ParsedFile`) that is
    folded into nested descriptors last.
11. The checks protoc makes:
    - undefined types and extendees;
    - duplicate symbols (enum values use C++ scoping), duplicate field and enum numbers (`allow_alias`);
    - reserved numbers and names, numbers 19000 to 19999;
    - an open enumeration's first value must be zero;
    - map key types, labels in oneofs, empty oneofs, proto3 `required` and defaults, editions labels;
    - extensions outside their extendee's ranges;
    - options that are unknown, of the wrong type, or set twice.

    Errors carry file, line and column.
12. `ProtoPrinter` writes source that compiles back to the same descriptor. It keeps every list's order, places groups and
    maps at their fields, prints options as dotted paths or text-format literals, and fully qualifies every name.
13. Oracle: 20 roots (the well-known types, `descriptor.proto`, the conformance and editions test messages, and fixtures for
    everything above, `Scripts/parser-corpus.py`) compile, imports included, to exactly protoc's bytes. Each printed file
    compiles back to protoc's descriptors. 19 of protoc's refusals are refused, and edge tests cover escapes, number forms,
    message literals and option errors.
14. `ProtoParser` is now the single-file front of the same parser: no imports, names left as written. The old lexer is gone.
15. Benchmarks: `Schema.compileDescriptorProto` takes 1.1 ms and 4,410 mallocs. `Schema.parse3Fields` went from 7 to 21
    mallocs (a full tokenizer and the flat model in place of the subset parser); its threshold was raised.

Not done:
- SourceCodeInfo (`--include_source_info`).
- Import visibility (a type used from a file that is not imported is accepted).
- protoc's warnings.
- Mutation coverage (deferred with the CI work).
