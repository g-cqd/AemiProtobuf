---
status: not-started
blocked-by: [0022, 0023]
date: 2026-10-29
---

# 0027 — proto2 in the macro

The conformance suite's second half is `TestAllTypesProto2`. Scope: `required` (decode refuses a message missing one, with its
path), explicit default values, groups as message fields (start and end group), closed enumerations (0023). Extensions: probe what
the suite asks of them and decide (ADR) between support and a recorded "not supported" failure list entry.
