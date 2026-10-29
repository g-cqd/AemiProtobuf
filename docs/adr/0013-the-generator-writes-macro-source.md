---
status: accepted
date: 2026-10-29
---

# 0013 — The generator writes `@ProtoMessage` source from descriptors

## Context

The conformance suite's messages are about 400 fields over proto2, proto3 and editions; existing `.proto` files are the usual
way a schema arrives. ADR-0011 makes the macro the main API, so generated code should be macro source a person could have
written, not a second runtime. Schema stays on the core alone (ADR-0001), and protoc already parses `.proto` completely.

## Decision

1. `AemiProtobufGenerator` (over `AemiProtobufSchema`) turns a `FileDescriptorSet` into one Swift file per `.proto`;
   `protoc-gen-aemi` runs it as a protoc plugin (`--aemi_out`, `--aemi_opt=visibility=public,unknown_fields=discard`), with
   proto3 `optional` and editions proto2 through 2023 declared supported. protoc parses; we do not depend on our own parser.
2. Semantics come from resolved features (edition defaults, then file, message and field features), so proto2, proto3 and
   editions share one path: explicit presence is `Optional`; `required` and `LEGACY_REQUIRED` are `required: true`; a message
   field is always `Optional` (it has presence); a closed enumeration is a raw-value one, an open one has `unrecognized(Int32)`;
   a group or a `DELIMITED` message is `.group`; an expanded repeated number is `packed: false`.
3. Names follow swift-protobuf: a package prefixes top-level types (`ProtobufTestMessages_Proto3_`), nested messages are
   nested types, a oneof is `OneOf_Name`, fields and enumeration values are lower camel case (a value loses its enumeration's
   name as a prefix), keywords are escaped, aliases are `static let`.
4. Bytes are `[UInt8]`: a nested type named `Data` (as `TestAllTypesProto2` has) would shadow `Foundation.Data`, and the
   generated code then needs no Foundation.
5. A field whose message can lead back to its own message by value is `@Indirect`; a oneof with such a member is an `indirect`
   enumeration.
6. Fields are declared in number order (a oneof at its first member's), so a message writes the bytes C++ writes.
7. An extension declared in the same file as its message becomes a field of it, except on a MessageSet, whose extensions stay
   unknown fields (their wire form is not a field's). Extensions from other files stay unknown fields (ADR-0012).
8. A proto2 `[default = …]` is a `nameOrDefault` accessor; the stored property stays `nil` when absent.
9. String fields always validate UTF-8, also in proto2, where C++ does not: a Swift `String` cannot hold what it would accept.
   Strict in the way ADR-0003 is for varints and tags.

## Consequences

- Generated files start with `// swift-format-ignore-file` and `// swiftlint:disable all` and say "Generated … Do not edit",
  which the analyzers recognize. In this repository they are named `Generated*.swift`, which the structure gate exempts.
- `Tests/AemiProtobufGeneratedTests` holds what the generator writes for the test protos; `GeneratorGoldenTests` regenerates
  them and requires the same text (`Scripts/generate-test-protos.sh` rewrites them).
- No reflection, no descriptor at run time, no JSON or text format: those are roadmap 0006 and 0010.
