---
status: done
blocked-by: []
date: 2026-10-29
---

# 0026 — oneof in the macro

From roadmap 0005's open list. Scope: an enumeration with one associated value per member (`@ProtoOneof`), the last member seen
wins, a message member merges when the same member repeats (0020). Red against `protoc --encode` of `oneof.proto`, which the schema
tests already hold.

## Done

`@ProtoOneof` on an enumeration whose cases each have `@ProtoField(n, kind)` and one associated value (scalar, string, bytes,
enumeration, message); the message holds it in `@ProtoOneofField var kind: Kind? = nil` (a second, peer-only macro: Swift refuses an
extension role on a property). The conformance (`AemiProtoOneof`) writes the member that is set even at its default (presence) and
claims a tag only for a member with its wire type; the message offers each unclaimed tag to its oneofs before the unknown fields. The
last member wins; the same message member given again merges, another member in between starts over; a closed enumeration member
with no case goes to the unknown fields and sets nothing. Oracles: three protoc encodings (`oneof-*.bin`). Diagnostics: a struct, a
case without a number, with no value or two, two cases in one declaration, a repeated value, a repeated number, a kind that does not
fit, a non-optional property. Red `0c9335e`. The generic `Codable` path does not know a oneof (its key is 0); it is fast-path only,
as maps are. Field numbers shared between a oneof and its message are not diagnosed: the macro sees one declaration at a time.
