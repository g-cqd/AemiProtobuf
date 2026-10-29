---
status: not-started
blocked-by: [0020]
date: 2026-10-29
---

# 0026 — oneof in the macro

From roadmap 0005's open list. Scope: an enumeration with one associated value per member (`@ProtoOneof`), the last member seen
wins, a message member merges when the same member repeats (0020). Red against `protoc --encode` of `oneof.proto`, which the schema
tests already hold.
