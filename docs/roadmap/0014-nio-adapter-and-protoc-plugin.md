---
status: done
blocked-by: []
date: 2026-10-25
---

# 0014 — NIO adapter and protoc plugin

Scope: `AemiProtobufNIO` (`ByteBuffer` zero-copy read, write into a buffer), gated like `AemiJSONNIO`; a `protoc-gen-aemi` plugin that emits `@ProtoMessage` structs from a `.proto`, so existing `.proto` files become Swift types without a code generator that owns the model.

## Done

`protoc-gen-aemi` (roadmap 0028, ADR-0013).

The NIO adapter (2026-10-30). `AemiProtobufNIO`, gated by `AEMIPROTOBUF_NIO` as AemiJSON's adapter is (swift-nio 2.104+):
- `WireReader.withReader(over: ByteBuffer)` and `ProtobufDecoder.decode(_:from: ByteBuffer)` read the readable bytes in place
  without moving the reader index.
- `ByteBuffer.writeProtobuf` and `writeProtobufFrame` write a message, or a varint or gRPC frame.
- `readProtobufFrame` returns the next frame's payload as a slice (no copy), or `nil` with nothing read until the frame is
  whole. It refuses an oversized length, a bad flag or a malformed varint. `readProtobuf` adds the decode.
- `ProtobufFrameDecoder` (a `ByteToMessageDecoder`; a partial frame at the end of the stream is an error) and
  `ProtobufFrameEncoder` (a `MessageToByteEncoder`) put the frames in a channel pipeline.

Tests (`AemiProtobufNIOTests`): reading and writing a buffer, both frame formats fed a byte at a time, bad frames, and an
`EmbeddedChannel` round trip through both handlers. CI runs them in the test job. That step was added but has not been seen to
run on CI.
