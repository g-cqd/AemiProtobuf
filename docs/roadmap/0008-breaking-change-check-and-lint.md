---
status: in-progress
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
