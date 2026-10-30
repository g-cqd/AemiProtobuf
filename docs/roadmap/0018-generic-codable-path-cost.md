---
status: done
blocked-by: []
date: 2026-10-25
---

# 0018 — Cost of the generic `Codable` path

Measured in `docs/research/2026-10-25-aemijson-vs-aemiprotobuf.md` (release, 2,000 nested records): `ProtobufDecoder` on a plain
`Codable` type takes 10.9 ms and ~70,000 allocations; AemiJSON's generic decoder takes 6.33 ms and 8,271. Encoding is the
other way round: 4.70 ms against 8.14 ms. The protobuf fast path takes 1.13 ms and 444 µs.

Scope: find where the decode time goes (profile before changing anything), then reduce it. Candidates, none measured yet:

- the per-message `[_ProtobufFieldEntry]` index and its `filter` per key (`entries(for:)`, `contains` then `decode` scans twice);
- a `_ProtobufDecoderImpl` and a `codingPath` array per field value;
- the packed-record expansion into a buffer of entries (24 bytes per element);
- on encode, a child `_ProtobufEncoderImpl` class per nested field value and per repeated element.

Memory is not the problem: one decode of 20,000 records retains 10.8 MB, against 9.3 MB for the fast path.

One improvement is already in: the repeated-element dispatch compares metatype identity instead of a chain of `as?` casts
(100,000 integers: encode 11.4 → 4.2 ms, decode 11.3 → 9.4 ms; one measurement each, same machine).

Acceptance: a re-run of `Scripts/compare.sh bench`, with the numbers before and after, no change to the bytes the oracle test
pins (`CodableOracleTests`), and the allocation thresholds updated with the change.

## Done (2026-10-30)

Profiled by allocation count first (the gate's 1,000-user corpus: 47,039 allocations per decode), then two changes:

1. Every scalar decode built its error path, `codingPath + [key]`, before knowing whether there was an error: an array per
   field. `_ScalarDecoding` now takes the path as an autoclosure, built only when it throws. 47,039 to about 37,000.
2. Every repeated or nested field filtered the message's entries into an array of its own, a nested message gathered its ranges
   into another, and every element of a repeated message was wrapped in a one-element array. `_FieldOccurrences` reads them in
   place from the index's entries (a window and a field number). To 29,028.

Wall clock, 2,000 records, release: decode 8.35 to 5.76 ms (AemiJSON's generic path: 4.64 ms); encode 4.10 to 3.25 ms. What
is left is mostly what `Codable` imposes (a box per keyed and unkeyed container), one index per message, and the strings
themselves. The thresholds are updated with the change; the oracle tests (`CodableOracleTests`) pass unchanged.
