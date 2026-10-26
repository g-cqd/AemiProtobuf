# AemiProtobuf — design

What is built is marked **(built)**. Everything else is the plan the roadmap carries out, and each unprobed claim in it is an open
question, listed at the end.

## Built: `AemiProtobufCore`

| Type | Job |
|---|---|
| `WireType`, `FieldNumber`, `FieldTag` | A tag cannot be built with field 0, a field above 2^29-1, or wire type 6 or 7 |
| `ZigZag` | `sint32` and `sint64` mapping |
| `WireReader` (+ `WireReader+Skip`) | Bounds-checked cursor: `nextTag`, varints, fixed values, `readString` (kernel UTF-8 validation), `readBytes`, `readMessage` (depth-counted sub-reader), `skipField` (iterative, depth-bounded group skipping) |
| `WireWriter` | `appendTag`, scalars, strings, bytes, raw, `appendMessage` (in-place length back-patch; rolls back on error) |
| `WireLimits`, `WireError` | Depth and size bounds; typed errors that carry the offset |

## Planned surface, by use

**Typed, fast.** `@ProtoMessage struct User { @ProtoField(1) var id: Int64 ... }` generates the fast-path conformances
(`AemiProtoFastDecodable` / `AemiProtoFastEncodable`, with a size or back-patch strategy chosen by probe) and the descriptor. The
coders dispatch to them as `AemiJSON.JSONDecoder` dispatches to `AemiJSONFastDecodable`. The type keeps its Codable conformance as
the fallback.

**Typed, interoperable.** `ProtobufEncoder().encode(value)` and `ProtobufDecoder().decode(T.self, from:)` for any
`Codable` type with integer `CodingKeys` (ADR-0004). Options mirror AemiJSON's: `userInfo`, `maxDecodingDepth`,
`maxEncodingDepth`, limits, a `.lenient` profile (ADR-0003), deterministic field order.

**Untyped.** A lazy `ProtoMessage` view over borrowed bytes: `message[8][1].string`, nil-safe like `JSON`. It indexes a message
once, so reading two fields out of a large message skips the rest. A `DynamicMessage` over a descriptor for tools.

**Definition.** `FileDescriptor`, `MessageDescriptor`, `FieldDescriptor`. A `.proto` parser (proto2, proto3, editions) and printer;
`FileDescriptorSet` read and written with the core itself, since `descriptor.proto` is protobuf. `T.protoDefinition` text from a
`@ProtoMessage` type, as `@Schemable` gives `jsonSchemaText`.

**Checking.** `descriptor.validate(bytes)`: wire types against the descriptor, UTF-8, packed and unpacked repeated, required
fields, depth. `Descriptor.breaking(from:)`: number reuse, type and label changes, with the wire-compatible classes (`int32` to
`int64`, `sint32` to `sint64` and `int32` to `bool` are wire-compatible; `int32` to `sint32` is not). `lint`: naming, reserved
ranges. Surfaced as library API and as a SwiftPM command plugin, like AemiJSON's plugins.

**Transport.** Frame readers and writers, sync and `AsyncSequence`: gRPC (1 flag byte, 4 length bytes), varint-delimited streams.
HTTP/2 and the transport itself are out of scope; swift-nio and grpc-swift own them. `AemiProtobufNIO` adapts `ByteBuffer`.

**JSON.** The proto3 JSON mapping (`AemiProtobufJSON`) through AemiJSON, for gRPC transcoding and debugging.

## Open questions (each has a roadmap probe)

1. Size-first, back-patch, or reverse writing for nested messages: which wins on this corpus? (0003)
2. Does a local inlinable varint loop beat the kernel call across the module boundary? (0003)
3. What does a borrowed string view save over `String` materialization on a decode that reads half the fields? (0006)
4. How do the coders perform against swift-protobuf, and against the hand path, on a frozen corpus? (0012)
5. Can the official conformance runner be built here, and which of its tests apply to a Swift-struct model? (0011)
6. Editions: how much of `.proto` editions syntax do consumers need? (0002)
