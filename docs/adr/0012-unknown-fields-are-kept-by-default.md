---
status: accepted
date: 2026-10-29
---

# 0012 — Unknown fields are kept by default, in a member the macro adds

## Context

A `@ProtoMessage` dropped every field its type does not declare, and a declared field that arrived with another wire type
(research 2026-10-29-conformance-review, findings 2 and 5). proto3 has kept unknown fields since 3.5; the conformance suite checks
it; a relay or a reader built against an older schema otherwise loses data silently. Our own caches never see an unknown field:
one type writes them and reads them.

`@ProtoMessage` was an extension macro, which cannot add a stored property. The bytes have to live in the value.

## Decision

1. `@ProtoMessage` also has a member role, which adds `var unknownFields = UnknownFields()` (with the type's access). `UnknownFields`
   (AemiProtobufCore) holds the raw bytes, tag and payload, in arrival order.
2. Decoding sends every field the generated `switch` does not take, including a declared field with another wire type, to
   `WireReader.readUnknownField(_:into:)`: the field is skipped as before, then its bytes are copied. Encoding writes them after
   the declared fields, as C++ does.
3. It is the default. `@ProtoMessage(unknownFields: .discard)` skips them and adds no member, for a format only its own writer reads.
4. The generic `Codable` path does not keep them: a `Codable` type has nowhere to put them. Documented on the coders.
5. Extensions are kept the same way: a proto2 extension the type does not declare is an unknown field, so it round-trips byte for
   byte. There is no typed extension API (roadmap 0027 decides whether one is needed).

## Consequences

- The memberwise initializer gains a trailing defaulted `unknownFields:` parameter, and synthesized `Equatable` and `Hashable`
  compare it, as swift-protobuf's `unknownFields` does: two messages that differ only in unknown fields are different values.
- A user property named `unknownFields` collides; the macro reports it.
- An empty `UnknownFields` is an empty array: no allocation, eight bytes in the value. Decoding pays nothing until an unknown tag
  arrives; then one copy of its bytes.
- analyzerkit's cache facts use `.discard` (its roadmap 0017), so they stay the smallest values.
