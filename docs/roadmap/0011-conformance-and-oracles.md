---
status: not-started
blocked-by: []
date: 2026-10-25
---

# 0011 — Conformance and oracles

Scope: build the official `conformance_test_runner` from the protobuf source (the Homebrew `protoc` 36.2 does not ship it; open question 5), drive it from a Swift testee, and record the failure list. Add a generated differential (seeded message generator, `protoc --encode` as oracle) to the existing mutation corpus.
