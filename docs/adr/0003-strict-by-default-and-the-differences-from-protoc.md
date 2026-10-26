---
status: accepted
date: 2026-10-25
---

# 0003 — Strict by default, and the two places that differ from protoc

## Context

Two parsers that disagree on one byte string are a request-smuggling and cache-poisoning primitive. `protoc` is the oracle, but it
is lenient in places.

## Evidence

`protoc --decode_raw` accepts a ten-byte varint whose last byte is 2 (`08 ff*9 02` prints `1: 9223372036854775807`), accepts the
same with last byte 1 (`UInt64.max`), and refuses an eleventh byte. Differential test over 1,500 seeded mutations of a protoc-made
message (`Tests/AemiProtobufCoreTests/Resources/decode-raw-verdicts.jsonl`): a second class the test found and nobody predicted: protoc accepts a tag varint above 32
bits (`90 94 cc a7 34 69`, value 14,041,680,400) and truncates it. Every other verdict agrees, in both directions.

## Decision

`WireReader` refuses both: a varint tenth byte above 1 is `malformedVarint`, and a tag above 32 bits is `invalidTag`. The test names
these two classes and fails on any other disagreement, and fails if the corpus stops containing one (so the allowance cannot go dead).

A later `.lenient` profile may accept both, as AemiJSON's profiles do. It would be opt-in and never the default.

## Consequences

Data written by a conforming encoder is accepted. Data that only `protoc`'s truncation makes parse is refused; no conforming encoder
produces it.
