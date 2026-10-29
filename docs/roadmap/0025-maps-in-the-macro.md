---
status: not-started
blocked-by: []
date: 2026-10-29
---

# 0025 — Maps in the macro

From roadmap 0005's open list; analyzerkit's caches use dictionaries (its ADR-0010 works around with repeated entries until this).

Scope: `[K: V]` with every map key kind and every value kind, as repeated entry messages (key 1, value 2); a missing key or value
is its default; a repeated key keeps the last; encode in sorted key order so bytes are deterministic. Red against
`protoc --encode` of a map fixture, and decode of entries in another order and with missing parts.
