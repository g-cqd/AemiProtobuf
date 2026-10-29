---
status: done
blocked-by: []
date: 2026-10-29
---

# 0027 — proto2 in the macro

The conformance suite's second half is `TestAllTypesProto2`. Scope: `required` (decode refuses a message missing one, with its
path), explicit default values, groups as message fields (start and end group), closed enumerations (0023). Extensions: probe what
the suite asks of them and decide (ADR) between support and a recorded "not supported" failure list entry.

## Done

- Groups: `@ProtoField(n, .group)` on an optional or repeated `@ProtoMessage` (or a oneof member), written between start-group
  and end-group tags (`WireWriter.appendGroup`, depth-bounded). `WireReader.readGroup` skips the group first to find its end, then
  hands `body` a reader over exactly its fields: a group merges as a message does; a group field given length-delimited is unknown.
- `required: true` on an `Optional` property. The coders ask `__aepbMissingRequired()` (protocol `AemiProtoRequiredFields`,
  generated where a message has required or message fields) after a whole decode and before an encode, as C++'s `IsInitialized`,
  so a field supplied by a later occurrence of its message counts; `WireError.missingRequired(path:)` names it (`many[1].a`).
- Closed enumerations: 0023. Explicit defaults change no byte (they are what a getter returns for an absent field); the generator
  (0028) writes them as accessors.
- Extensions, decided (ADR-0012 point 5): an extension a type does not declare is an unknown field and round-trips byte for byte;
  the suite's MessageSet tests rely on exactly that. The one extension test that needs a typed field (`RejectInvalidUtf8.String.Extension`)
  is served by the generator turning an extension declared in the same file into a field of the extended message (0028); no
  extension registry.
- The walk is allocation-free when nothing is missing, which the allocation gate checks: a first version of the containers'
  walks was not `@inlinable`, ran unspecialized across the module boundary and copied each large element into a heap buffer
  (+2,000 allocations for 1,000 users, encode and decode); inlinable and indexed, the counts are back to the thresholds.
- Probed first: the conformance suite does not use `TestAllRequiredTypesProto2`; required fields are implemented for the
  specification, not the suite. Red `a7d1b11` (protoc oracles `groups.bin`, `required.bin`).
