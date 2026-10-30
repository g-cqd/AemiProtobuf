---
status: done
blocked-by: []
date: 2026-10-25
---

# 0008 — Breaking-change check and lint

Scope: compare two `FileDescriptorSet`s; report field number reuse, type change by wire-compatibility class, label change, removed field without `reserved`, enum value changes; lint for naming and reserved ranges. Library API, then a SwiftPM command plugin. Compare with `buf breaking` on a fixture corpus; record every difference.

## Done

`SchemaComparator`: messages and enums matched by fully qualified name, nested ones included; fields matched by number (the wire's
identity), so a rename is reported as `fieldRenamed` and is not a wire break (`breaksTheWire`); removed field, renumbered field
(the name moved), incompatible type by wire-compatibility class (varint integers with bool and enum, `sint32` with `sint64`, the
fixed pairs, `string` with `bytes`, message with `bytes`), changed message or enum type name, changed label, removed enum, removed
or renumbered enum value. Deterministic order. Tests for each.

## Open

- Reserved ranges and names (the descriptor model does not carry them yet), the `reserved` check on removal, field-number reuse.
- Lint: naming and reserved-range rules.
- The command plugin, and the `buf breaking` oracle corpus (`buf` is not installed here).
- `oneof` membership changes, JSON-name changes, and proto2 label rules.
- Comparator allocations: 269 for 50 messages, up from 206 with the first version (roadmap queue, performance only).

## Done (2026-10-30)

- The oracle: `buf breaking` 1.75 with the WIRE rules on fourteen schema changes, one per kind (`Scripts/breaking-corpus.py`,
  protoc descriptor sets as buf images). Every pair reports exactly buf's rules (`BufBreakingOracleTests`). Each change names its
  buf rule (`bufRule`); `breaksTheWire` is whether it is a WIRE rule.
- New: a removed field or value whose number the new version reserves is not reported; reserved ranges (a shrink counts) and names
  the new version drops (`RESERVED_MESSAGE_NO_DELETE`, `RESERVED_ENUM_NO_DELETE`); a field moved into, out of or between oneofs
  (`FIELD_SAME_ONEOF`); a changed set of required fields (`MESSAGE_SAME_REQUIRED_FIELDS`, which buf adds to the cardinality
  change of required to optional); a changed JSON name (`FIELD_SAME_JSON_NAME`, not WIRE). Changed after buf: a removed
  message or enumeration is reported as not breaking the wire (buf files it under FILE).
- Lint: `SchemaLinter`, buf's BASIC naming rules and `ENUM_NO_ALLOW_ALIAS` / `ENUM_FIRST_VALUE_ZERO`, as buf reads them (an
  upper-case first letter and no underscore is PascalCase; digits do not split snake case), against `buf lint` on a file of
  violations (`BufLintOracleTests`: the same rules and names); plus `RESERVED_RANGE_HOLDS_FIELD`.
- Tools: `aemi-proto-check lint SET.pb` / `breaking OLD.pb NEW.pb [--all]` (exit 1 on findings), and the command plugin
  `swift package protobuf-check …`.
- Comparator allocations: 269 to 69 for 50 messages (a linear search instead of two dictionaries per message); threshold lowered.

Not done: proto2-specific label rules beyond cardinality and required fields (buf has none in WIRE), and buf's FILE and PACKAGE
categories (names, packages, files), which concern source compatibility rather than the wire.
