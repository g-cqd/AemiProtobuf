---
status: in-progress
blocked-by: []
date: 2026-10-25
---

# 0009 — Framing and streaming

Scope: gRPC frames (flag byte, big-endian length), varint-delimited messages, a push parser for partial input, and an `AsyncSequence` over any async byte source, as `JSONEventAsyncSequence`. Every length is bounded by a limit before any allocation. Tests: a frame split at every byte offset; a declared length of 4 GiB.

## Done

`FrameDecoder` (a push parser for gRPC frames and varint-delimited messages), `FrameEncoder`, `FrameAsyncSequence` over any async
chunk source. A declared length over `maxFrameBytes` is refused when the header is complete, before any payload is buffered; a
decoder that has failed repeats its error; the buffer is compacted so a long stream holds a bounded amount. Tests: a stream split
at every byte offset and in single bytes, the gRPC example frame, the flag bits, a 4 GiB length, the inclusive limit, ten-byte
varint lengths, a stream that ends inside a frame, 1,000 frames in a row, the compaction boundaries, the async source's errors and
end. Mutation: 50 of 50 on `FrameDecoder`.

## Open

- Integration with the coders (encode and decode a message straight to or from a frame), and a `Data` convenience.
- Server-streaming helpers, a compressed-frame hook, and a benchmark (against `grpc-swift` and AemiJSON's `parseLines`).
