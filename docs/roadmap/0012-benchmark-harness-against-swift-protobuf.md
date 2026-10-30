---
status: done
blocked-by: []
date: 2026-10-25
---

# 0012 — Benchmark harness against swift-protobuf

Scope: a frozen corpus and a script, as `aemiregex/Scripts/bench-compare.sh`; ordo-one `package-benchmark` for percentiles and malloc counts; swift-protobuf, and later a Rust `prost` and a C++ build, as peers. Replace the indicative numbers in ADR-0005 with harness numbers. Release only.

Before the speed items (0017, 0018, 0019) change code: their before-and-after numbers come from this harness, and the fixes of
0020–0023 add decode work whose cost it must show (research 2026-10-29-conformance-review).

## Done

The harness is `Benchmarks/Comparison` with `Scripts/compare.sh` (seeded, so frozen, corpus; package-benchmark percentiles and
allocation counts; swift-protobuf as the generated peer; a report script), now with a C++ peer: `compare.sh cpp` builds the
protoc `--cpp_out` code for `comparison.proto` against the installed libprotobuf and times the same 2,000-record message
(heap and arena decode, encode). The run after the conformance work is research 2026-10-30-harness-after-conformance; it is the
"before" of 0017, 0018 and 0019. ADR-0005's figures were a one-off probe of a hand path and stay as its evidence; the harness
numbers are the ones to compare against. Rust `prost` is not a peer: no Rust toolchain is part of this repository's tooling, and
C++ is the reference implementation.
