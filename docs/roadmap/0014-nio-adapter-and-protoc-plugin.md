---
status: in-progress
blocked-by: []
date: 2026-10-25
---

# 0014 — NIO adapter and protoc plugin

Scope: `AemiProtobufNIO` (`ByteBuffer` zero-copy read, write into a buffer), gated like `AemiJSONNIO`; a `protoc-gen-aemi` plugin that emits `@ProtoMessage` structs from a `.proto`, so existing `.proto` files become Swift types without a code generator that owns the model.

## Done

`protoc-gen-aemi` (roadmap 0028, ADR-0013).

## Open

The NIO adapter.
