# 2026-10-30 — The comparison after the conformance work, with a C++ peer

The question: what did merging, unknown fields, the required-field walk, groups and maps cost the macro path, and how far is it
from C++? `Scripts/compare.sh all` and `Scripts/compare.sh cpp` (release, one machine, arm64; package-benchmark p50; the C++
peer times the same 2,000-record message with `std::chrono`, at least 200 samples or 2 s). Raw results are untracked
(`Benchmarks/Comparison/results`).

## Records, 2,000 (p50)

| codec | encode | decode | round trip |
|---|---:|---:|---:|
| AemiProtobuf macro | 517 µs, 12 allocations | 880 µs | 1.24 ms |
| swift-protobuf 1.39 | 1.05 ms, 4,001 allocations | 1.18 ms | 1.98 ms |
| C++ libprotobuf 36.2 | 339 µs | 725 µs (arena: 384 µs) | |
| AemiJSON macro | 1.09 ms | 1.74 ms | 2.70 ms |
| AemiProtobuf generic `Codable` | 4.10 ms | 8.35 ms, ~70,000 allocations | 11.6 ms |

Against the 2026-10-25 run (440 µs encode, 1.15 ms decode): decode is not slower, encode 17 % slower or noise; the walk for
required fields allocates nothing (the allocation gate pins that), unknown fields cost nothing when there are none. Decode has a
fixed allocation count per record (strings and arrays), so the remaining gap to C++'s arena is allocation, not parsing.

## Where AemiProtobuf trails swift-protobuf (encode only)

| workload | AemiProtobuf | swift-protobuf | gap |
|---|---:|---:|---|
| 100,000 wide integers | 458 µs | 323 µs | 1.42× |
| 100,000 small integers | 244 µs | 138 µs | 1.77× |
| 20,000 ASCII strings | 372 µs | 189 µs | 1.97× |
| 20,000 multi-byte strings | 382 µs | 189 µs | 2.02× |

Doubles encode 12.1 against 18.5 µs; every decode row is ahead or equal. These are roadmap 0019's targets. The generic `Codable`
decode (8.35 ms, 1.8× AemiJSON's generic path) is 0018's.
