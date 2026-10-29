---
status: not-started
blocked-by: []
date: 2026-10-29
---

# 0020 — Merge a message field given twice

Research 2026-10-29-conformance-review, finding 1. `pair {a: 1}` then `pair {b: 2}` decodes to `a = 0, b = 2`; the encoding
guide merges, to `a = 1, b = 2`, for singular and optional message fields (a repeated message field appends, as today; a scalar's
last occurrence wins, as today).

Scope: the generated decoder decodes a second occurrence into the value it already holds; the generic `Codable` decoder does the same.
Red: hand-written bytes for singular, optional and nested-two-levels merges, and a scalar's last occurrence still winning; the
protoc oracle (`protoc --decode` of concatenated encodings) agrees.

Acceptance: green, the existing oracles unchanged, decode allocation thresholds unchanged (a merge costs nothing when a field
occurs once).
