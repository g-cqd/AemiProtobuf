---
date: 2026-10-30
status: answered
roadmap: [0006]
---

# Lazy view against full decoding, and the dynamic message's cost

Open question 3 of the roadmap: is a message read in place worth having beside the macro decoder, for a reader that wants a
few fields? The probe reads half the fields of each user of the 1,000-user corpus (id, name, active, the address's city,
stamp) through `ProtoMessageView` and after a full `MacroUsers` decode (`Benchmarks/AemiProtobufSuite/ViewBenchmarks.swift`;
release, Apple M-series, the benchmark package's p50). The view borrows strings (`withBytes`), so it makes no `String`.

| Path | Wall clock p50 | Mallocs |
|---|---|---|
| Full macro decode, then the five fields | 771 µs | 6,011 |
| `ProtoMessageView`, first version | 924 µs | 8,024 |
| `ProtoMessageView`, index reserved | 507 µs | 2,019 |

## Findings

- The macro decoder is hard to beat: short strings are stored inline in `String` (the corpus's names fit 15 bytes), so a full
  decode costs six allocations per user. The view's first version lost to it: growing each message's index array took four or
  five allocations per message.
- Reserving the index once (two bytes per field at least, capped at 32 entries) brought the view to one allocation per message
  and 1.5× ahead of the full decode. The view indexes every field of the messages it opens, so its advantage grows as fewer
  messages are opened and as strings get longer, and shrinks to nothing when every field is read.
- Answer: keep both. The view is for reading a few fields, routing, or filtering without a type; the macro decoder stays the
  path for reading a message whole.

## The dynamic message on the same corpus

`DynamicSchema` decodes and encodes the corpus from hand-built descriptors. Each step below was measured:

| Step | Decode | Decode mallocs | Encode |
|---|---|---|---|
| First version (`indirect enum`, structs) | 6.37 ms | 41 K | 3.46 ms |
| Only `.message` boxed | 5.42 ms | 21 K | 3.51 ms |
| `DynamicField` and `DynamicMessageType` as classes, dense number lookup | 3.51 ms | 21 K | 2.04 ms |
| Values dictionary taken out before finishing; packed runs read into a reserved array | 3.06 ms | 17 K | 2.04 ms |

An `indirect enum` boxes every case, so every scalar was a heap allocation. A field read copied the field's descriptor (strings,
option bytes, sets) and the message type's tables, dozens of retains per field. The dynamic path ends about 4× slower than the
macro decoder, which knows the layout at compile time. That is the expected price of a path driven by descriptors.
