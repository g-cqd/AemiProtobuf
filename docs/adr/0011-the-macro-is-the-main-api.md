---
status: accepted
date: 2026-10-25
---

# 0011 — `@ProtoMessage` is the main API

## Context

The first draft made the fast path a protocol to be written by hand (ADR-0009) and the `Codable` coders the general route. The
comparison (`docs/research/2026-10-25-aemijson-vs-aemiprotobuf.md`) shows what each costs: a hand-written or generated fast path
encodes 2,000 records in 444 µs and decodes them in 1.12 ms; the generic `Codable` path takes 4.60 ms and 11.3 ms and allocates
about 8 times as often (roadmap 0018). Nobody should reach the slow path by default.

## Decision

- A message is a struct marked `@ProtoMessage`, each property `@ProtoField(number)`. The macro generates the fast path and
  `Codable`, so the type works with `ProtobufEncoder`, `ProtobufDecoder`, and any `Codable` code, and the coders always find
  the fast path.
- Field numbers are explicit and required. Declaration order is not a schema: a reordered struct must not change the wire format.
- Kinds the Swift type cannot say (`sint*`, `fixed*`, `sfixed*`, enumerations) are the second argument. Everything else is
  inferred from the type as written.
- The macro refuses what it cannot express (maps, `oneof`, a missing number or default, a kind that does not fit the type, a
  repeated or reserved number) with a diagnostic at the property. It does not fall back to a slower path: that would hide a 10x
  cost behind a successful build.
- The generated code names `WireReader`, `WireWriter`, `WireError` and `ZigZag`; `AemiProtobuf` re-exports the core so one
  import is enough.
- A generated decoder starts from `Self()`, so every property needs a default.
- Decoding: the last occurrence of a singular field wins; a field with another wire type, an unknown field and an enumeration
  number with no case are skipped, as protoc skips unknown data.

## Consequences

- `swift-syntax` is a dependency of `AemiProtobuf` (range 603 to 605, as AemiJSON), used by the compiler plugin only.
- The hand-written fast path stays possible: the protocols are public.
- A schema-first route (generate the struct from `.proto`) is a separate tool (roadmap 0014), not this macro.
