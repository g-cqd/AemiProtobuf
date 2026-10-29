---
status: done
blocked-by: []
date: 2026-10-29
---

# 0023 — Open enumerations keep unknown values

Research 2026-10-29-conformance-review, finding 3. `28 07` against an enumeration without case 7 leaves the field unchanged.
proto3 enumerations are open; proto2 ones are closed and send an unknown value to the unknown fields.

Scope: an enumeration may declare where an unknown number goes (a protocol with `init(unrecognized:)` and `unrecognizedValue`, as
swift-protobuf's `UNRECOGNIZED(Int)`); one that does not is treated as closed and its unknown numbers go to the unknown fields
(0022), including inside a packed run. Red: singular, optional and packed, both kinds, round trips byte for byte.

## Done

No new protocol: an enumeration is open when its `init(rawValue:)` cannot fail (a hand-written `RawRepresentable` with a case
such as `unrecognized(Int32)`), closed when it can (a raw-value enumeration). The generated code reads through
`ProtoEnumeration.value(_:_:)`, which calls the initializer through the protocol so both spellings compile. A closed
enumeration's number with no case becomes an unknown varint field (`UnknownFields.appendVarint(field:_:)`), one record per element
inside a packed run, as C++ does; with `.discard` it is dropped. Red `298609c` (the open case passed once the helper existed, to
compile; three closed cases failed). The roadmap's protocol with `init(unrecognized:)` was not needed.
