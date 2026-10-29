---
status: not-started
blocked-by: [0025, 0026, 0027]
date: 2026-10-29
---

# 0028 — Swift source from a descriptor set

The conformance messages are about 400 fields; writing them by hand invites exactly the errors the suite looks for. Scope: a
generator from a `FileDescriptorSet` (`protoc --descriptor_set_out`, read by AemiProtobufSchema) to `@ProtoMessage` source; the
first step of roadmap 0014's `protoc-gen-aemi`. Needs from roadmap 0002: maps (`map_entry`), nested types, groups, defaults,
`packed` and the other options the generator reads. Red: the generated types for `kinds.proto` and `oneof.proto` match the
hand-written ones byte for byte on their oracles.
