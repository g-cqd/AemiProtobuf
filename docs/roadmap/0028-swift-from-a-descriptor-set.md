---
status: done
blocked-by: []
date: 2026-10-29
---

# 0028 — Swift source from a descriptor set

The conformance messages are about 400 fields; writing them by hand invites exactly the errors the suite looks for. Scope: a
generator from a `FileDescriptorSet` (`protoc --descriptor_set_out`, read by AemiProtobufSchema) to `@ProtoMessage` source; the
first step of roadmap 0014's `protoc-gen-aemi`. Needs from roadmap 0002: maps (`map_entry`), nested types, groups, defaults,
`packed` and the other options the generator reads. Red: the generated types for `kinds.proto` and `oneof.proto` match the
hand-written ones byte for byte on their oracles.

## Done

ADR-0013. `AemiProtobufGenerator` and the `protoc-gen-aemi` plugin (the plugin half of roadmap 0014). The descriptor model
was completed first (roadmap 0002, item 8), and the macro learned `packed: false` and `[UInt8]` as an optional, repeated and
map-value bytes field, both of which the generated code needs. `Tests/AemiProtobufGeneratedTests` holds the generator's output
for the test protos (kinds, maps, oneof, proto2 groups and required, expanded repeated, merge): it compiles and reads and writes
protoc's bytes; `GeneratorGoldenTests` regenerates it and requires the same text, checks public visibility, option parsing, an
unknown type and the plugin's request and response. The generator was drafted before these tests; a mutation (packing every
repeated number) shows they catch a semantic change.
