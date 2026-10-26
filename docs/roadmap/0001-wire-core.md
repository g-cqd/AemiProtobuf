---
status: done
blocked-by: []
date: 2026-10-25
---

# 0001 — Wire core

## Done

`AemiProtobufCore`: tags, varints, zig-zag, bounded reader and writer, limits, typed errors with offsets. 42 tests in debug and release: protocol vectors from the encoding guide, bytes produced by `protoc` 36.2, a 1,500-case differential against `protoc --decode_raw`, 14 mutants all killed (diary 2026-10-25-01).

## Still open (not blocking)

- `Data` entry point (umbrella, 0003).
- A `.lenient` profile for the two strict refusals (ADR-0003). No consumer asked for it.
