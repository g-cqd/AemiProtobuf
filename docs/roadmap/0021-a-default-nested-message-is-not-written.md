---
status: done
blocked-by: []
date: 2026-10-29
---

# 0021 — A non-optional nested message at its default is not written

Research 2026-10-29-conformance-review, finding 4. `ZZHolder(wide: -1)` writes `0a 00` for its empty `pair`, against the macro's
own rule that a non-optional field at its default is left out. Two bytes per empty nested message in every cache entry.

Scope: the generated encoder leaves out a non-optional message field whose encoding is empty (the length is known before the tag
is committed, so no `Equatable` is needed); an `Optional` message keeps explicit presence and is written when present.
Red: the bytes of an empty and a non-empty nested message, optional and not; the `kinds` oracle re-recorded only if `protoc` agrees.

Acceptance: green, the comparison's bytes still identical to swift-protobuf's.

## Done

`WireWriter.appendNonEmptyMessage(field:_:)` abandons a message whose body wrote nothing; the macro uses it for non-optional message
fields. Optional ones keep presence (`12 00`), repeated ones one record per element. The test that pinned the old bytes
(`MacroOracleTests`, `8a 01 00` for an empty `Kinds`) now expects nothing written. The `kinds` oracle is unchanged: its sample's
nested message is not empty. Proto3 message fields have presence, so a generated type (0028) maps them to `Optional`; a
non-optional message field is the hand-written choice of "absent means default".
