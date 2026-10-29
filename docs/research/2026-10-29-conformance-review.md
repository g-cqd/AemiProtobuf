# 2026-10-29 — Conformance, correctness and speed: where AemiProtobuf stands

The question: before analyzerkit puts every tool's cache on `@ProtoMessage` (its roadmap 0017), what does AemiProtobuf get wrong
against the protobuf specification, what can the official conformance suite tell us, and where is it still slow?

## Method

A throwaway test (`@ProtoMessage` types with a nested message, an optional message, a packed `[Int32]`, a bool, a string, an
enumeration, `Int32` and `UInt32`) decoding hand-written bytes, each case checked against the encoding guide and what
`protoc`/C++ does. Release numbers are from `2026-10-25-aemijson-vs-aemiprotobuf.md`; nothing new was timed.

## What it gets right

| case | bytes | result |
|---|---|---|
| packed field written unpacked, then packed | `10 01 10 02 12 02 03 04` | `[1, 2, 3, 4]` |
| bool from varint 2, and from a ten-byte varint | `18 02` | `true` |
| invalid UTF-8 in a `string` | `22 02 c3 28` | refused (`invalidUTF8`) |
| `int32` from a 64-bit varint `0x1_0000_0001` | | `1`, truncated as C++ does |
| `int32` −1 as ten bytes; encoding −1 | | `-1`; ten bytes written |
| `uint32` from a 64-bit varint | | truncated |
| field number 0; end-group with no start; eleven-byte varint; length past the end | | each refused |
| an unknown group | `fb 01 08 01 fc 01` | skipped |

## What it gets wrong

1. **A message field given twice replaces instead of merging.** `0a 02 08 01 0a 02 10 02` (`pair {a: 1}` then `pair {b: 2}`)
   decodes to `a = 0, b = 2`; the specification merges, to `a = 1, b = 2`. Optional message fields too. Silent data loss on
   any input that was concatenated or written field by field, which the specification allows.
2. **Unknown fields are dropped.** `18 01 f8 01 05` (a known bool, then field 31) re-encodes as `0a 00 18 01`: field 31 is gone.
   proto3 has preserved unknown fields since 3.5; a relay or a reader on an older schema loses data.
3. **An unknown value of an open enumeration is lost.** `28 07` against an enumeration with no case 7 leaves the field at its
   default. proto3 enumerations are open: the value must survive (swift-protobuf keeps `UNRECOGNIZED(7)`; C++ keeps the integer).
4. **A default nested message is written.** `ZZHolder(wide: -1)` encodes as `0a 00 38 …`: the empty `pair` costs two bytes.
   Harmless on decode, but against the macro's own rule ("a non-optional field holding its default is left out") and a cost on
   every cache entry with an empty nested message.
5. **A known field with another wire type is skipped**, where C++ keeps it as an unknown field. Becomes correct with (2).

## What the conformance suite needs that does not exist

The official runner sends `TestAllTypesProto3` and `TestAllTypesProto2` in binary and JSON and expects them back. To answer it, the
testee needs, beyond the five fixes above:

- maps of every key and value kind; `oneof`; a message that holds itself (`recursive_message`, and `NestedMessage.corecursive`), which
  a Swift struct cannot hold by value, so indirect storage;
- proto2: `required`, explicit defaults, groups as fields, closed enumerations (an unknown value goes to the unknown fields),
  extensions;
- the well-known types as messages (binary needs nothing special);
- for the JSON half, the proto3 JSON mapping (roadmap 0010); the testee may answer "skipped", which the runner counts apart.

The runner is not in Homebrew's protobuf 36.2. The v36.2 sources build it with CMake (`protobuf_BUILD_CONFORMANCE=ON`) against the
installed abseil; ninja and cmake are installed. Writing `TestAllTypesProto3` and `Proto2` by hand (about 400 fields) invites the
errors the suite looks for, so a generator from a descriptor set comes first (`protoc --descriptor_set_out`, then our descriptor
reader; the start of roadmap 0014's plugin). That needs maps, nested types, groups, defaults and options in the descriptor model
(roadmap 0002).

## Where it is slow (known, from the 2026-10-25 comparison)

| path | AemiProtobuf | reference | gap | item |
|---|---:|---:|---|---|
| integer encode, 100,000 wide / small | 523 / 261 µs | swift-protobuf 396 / 171 µs | 1.3–1.5× slower | 0019 |
| string encode, 20,000 | 416–498 µs | swift-protobuf 223–292 µs | 1.7–1.9× slower | 0019 |
| generic `Codable` decode, 2,000 records | 11.1 ms, ~70,000 allocations | AemiJSON generic 6.5 ms, 8,271 | 1.7× slower, 8× allocations | 0018 |
| schema parse, three fields | 3,625 ns, 19 mallocs | itself before the checks: 2,085 ns, 5 | 1.7× slower, 4× mallocs | 0017 |
| comparator, 50 messages | 269 allocations | itself before: 206 | +30 % | 0008 |
| `readVarint` in the reader | 4.8 ns per varint | an isolated loop: 1.6 ns | 3× | not filed; no workload limited by it |

Not measured at all: maps, `oneof`, merging, unknown-field preservation (none exist), the validator against a peer, framing against
`grpc-swift`, Linux. The comparison harness is a script over `package-benchmark` but has no frozen corpus or regression gate
(roadmap 0012); the allocation thresholds are the only gate on speed.

The fast path itself is ahead where analyzerkit uses it: decoding 2,000 records 1.15 ms against swift-protobuf 1.45 ms and the
AemiJSON macro 2.30 ms. The fixes above must keep that: merging and unknown-field storage add work on the decode path.
