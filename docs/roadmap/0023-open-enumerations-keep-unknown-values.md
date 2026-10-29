---
status: not-started
blocked-by: []
date: 2026-10-29
---

# 0023 — Open enumerations keep unknown values

Research 2026-10-29-conformance-review, finding 3. `28 07` against an enumeration without case 7 leaves the field unchanged.
proto3 enumerations are open; proto2 ones are closed and send an unknown value to the unknown fields.

Scope: an enumeration may declare where an unknown number goes (a protocol with `init(unrecognized:)` and `unrecognizedValue`, as
swift-protobuf's `UNRECOGNIZED(Int)`); one that does not is treated as closed and its unknown numbers go to the unknown fields
(0022), including inside a packed run. Red: singular, optional and packed, both kinds, round trips byte for byte.
