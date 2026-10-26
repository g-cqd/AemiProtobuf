---
status: accepted
date: 2026-10-25
---

# 0001 — Layering: a Foundation-free wire core under a Codable and macro surface

## Context

The request: an AemiJSON-shaped protobuf package that encodes and decodes through custom fast paths or through
`Encodable`/`Decodable`, and provides the tools for checking and definition. AemiJSON's shape is the model: a Foundation-free
engine (`AemiJSONCore`), an umbrella with Codable, macros and schema, and gated adapters (NIO).

## Decision

| Target | Contains | Depends on |
|---|---|---|
| `AemiProtobufCore` (built) | tags, varints, zig-zag, bounded `WireReader` / `WireWriter`, limits, errors | AemiKernel, AemiKernels |
| `AemiProtobufSchema` | descriptors, `.proto` parser and printer, wire validation, breaking-change check | Core |
| `AemiProtobuf` | `ProtobufEncoder` / `ProtobufDecoder`, fast-path protocols, `@ProtoMessage`, `Data` interop, framing | Core, Schema, swift-syntax (macro target only) |
| `AemiProtobufJSON` | the proto3 JSON mapping, over AemiJSON | AemiProtobuf, AemiJSONCore |
| `AemiProtobufNIO` | `ByteBuffer` interop, opt-in | AemiProtobuf, swift-nio |

The wire core has no knowledge of messages, so a hand-written fast path, the Codable coders and the macro output all sit on one
reader and one writer, and a bug in varint or UTF-8 handling is fixed once.

## Alternatives

- **One module.** Rejected: a consumer that only frames bytes would link a Codable coder and swift-syntax.
- **Wrap swift-protobuf.** Rejected for the engine: its generated types own the message model, so neither Codable conformance nor
  a macro fast path on plain Swift structs is possible, and the benchmark peer would be the dependency.

## Consequences

Each target is a separate roadmap entry (0001 to 0010). Only `AemiProtobufCore` exists. The package resolves the Aemi package's graph, as
`AemiJSONCore` does (its modules stay free of swift-syntax and Foundation, the resolved graph does not).
