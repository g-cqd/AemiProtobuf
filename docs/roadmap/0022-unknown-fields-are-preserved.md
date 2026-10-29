---
status: not-started
blocked-by: []
date: 2026-10-29
---

# 0022 — Unknown fields are preserved

Research 2026-10-29-conformance-review, findings 2 and 5. Decoding then encoding drops every field the type does not declare, and
a declared field with another wire type. proto3 preserves them (since 3.5); the conformance suite checks it.

Decide first (ADR): where the bytes live. `@ProtoMessage` is an extension macro and cannot add a stored property; a member role can
(`var unknownFields: UnknownFields`), which changes the memberwise initializer and `Equatable` (as swift-protobuf's `unknownFields`
does). Preserve by default, opt out per type (`@ProtoMessage(unknownFields: .discard)`) where a cache wants the smallest decode.
Measure the cost of an empty `UnknownFields` on decode and on memory first.

Red: unknown varint, fixed, length-delimited and group fields kept in order and written back after the known fields; a known
field with another wire type kept; `.discard` drops them; equality includes them.

Acceptance: green; decode time and allocations of the comparison corpus (no unknown fields) within the thresholds.
