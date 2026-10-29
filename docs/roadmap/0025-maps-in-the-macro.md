---
status: done
blocked-by: []
date: 2026-10-29
---

# 0025 — Maps in the macro

From roadmap 0005's open list; analyzerkit's caches use dictionaries (its ADR-0010 works around with repeated entries until this).

Scope: `[K: V]` with every map key kind and every value kind, as repeated entry messages (key 1, value 2); a missing key or value
is its default; a repeated key keeps the last; encode in sorted key order so bytes are deterministic. Red against
`protoc --encode` of a map fixture, and decode of entries in another order and with missing parts.

## Done

`[Key: Value]` with `@ProtoField(n, key:, value:)` for kinds Swift cannot tell; diagnosed: a key protobuf cannot key on (float,
double, bytes, enumeration, message), a positional kind on a map, `key:`/`value:` on a non-map, a nested collection value, the
`Dictionary<…>` spelling. Entries write key and value even at their defaults, in `ProtoMap.sorted` order (numbers by value,
strings by UTF-8 bytes, `false` first): byte for byte `protoc --encode --deterministic_output` on `maps.bin`. Decode: missing key or
value is its default, a repeated key keeps the last, a message value merges, unknown fields inside an entry are skipped, a closed
enumeration value with no case sends the entry to the unknown fields. Red `71f7242`. The generic `Codable` path still refuses
dictionaries (ADR-0010); maps are a fast-path feature. Allocation thresholds unchanged.
