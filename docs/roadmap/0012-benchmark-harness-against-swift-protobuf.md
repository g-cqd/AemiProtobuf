---
status: not-started
blocked-by: []
date: 2026-10-25
---

# 0012 — Benchmark harness against swift-protobuf

Scope: a frozen corpus and a script, as `aemiregex/Scripts/bench-compare.sh`; ordo-one `package-benchmark` for percentiles and malloc counts; swift-protobuf, and later a Rust `prost` and a C++ build, as peers. Replace the indicative numbers in ADR-0005 with harness numbers. Release only.

Before the speed items (0017, 0018, 0019) change code: their before-and-after numbers come from this harness, and the fixes of
0020–0023 add decode work whose cost it must show (research 2026-10-29-conformance-review).
