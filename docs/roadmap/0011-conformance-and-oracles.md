---
status: done
blocked-by: []
date: 2026-10-25
---

# 0011 — Conformance and oracles

Scope: build the official `conformance_test_runner` from the protobuf source (the Homebrew `protoc` 36.2 does not ship it; open question 5), drive it from a Swift testee, and record the failure list. Add a generated differential (seeded message generator, `protoc --encode` as oracle) to the existing mutation corpus.

Order (research 2026-10-29-conformance-review): the macro's correctness first (0020–0023), then what the conformance messages need
(0024–0027), the generator (0028), then this. Build the runner from protobuf v36.2 (the `protoc` here) with CMake against the
installed abseil; a testee executable in a dev-only package, as `Benchmarks/Comparison`; JSON requests answered "skipped" until
0010. Acceptance: the runner's binary tests pass for proto3 and proto2, each remaining failure in a committed failure list with a
reason, and the run in CI or, if the runner build is too slow for it, a script and the recorded result.

## Done

The official suite from protobuf v36.2, built with CMake against the installed abseil (`Scripts/conformance.sh`, which also
regenerates the testee's sources with protoc-gen-aemi): `Conformance/`, a dev-only package whose testee answers binary requests
for `TestAllTypesProto3`, `TestAllTypesProto2`, the editions proto2 and proto3 copies and `TestAllTypesEdition2023`, and
"skipped" for JSON, JSPB and text format. Result with `--enforce_recommended`: **2,833 passed, 0 failed**, 2,816 skipped (JSON and
JSPB) in the binary and JSON suite; the text-format suite skips all 909. The failure list is empty.

The run found two defects, each fixed red then green: a message with no fields did not compile (`CodingKeys` with no case and
a raw type; `google.protobuf.Empty`), and a tag written in more than five bytes was accepted (`BadTag_OverlongVarint`, four
tests). CI job `conformance` builds the runner and protoc from the same tag (cached by protobuf and abseil version) and runs it.

## Open

- JSON and text format (2,816 and 909 tests): roadmap 0010 and a text-format item.
- The generated differential (a seeded message generator with `protoc --encode` as the oracle).

## Done (2026-10-30): text format, and the whole suite

- `ProtoTextFormat` (AemiProtobufSchema) reads and writes protobuf's text format over dynamic messages. Reading accepts:
  - `#` comments, `{ }` or `< >`, an optional `:` before a message, lists, and `,` or `;` between fields;
  - integers in every base, `inf` / `nan` in any case, an `f` suffix, adjacent strings with C escapes;
  - groups (and editions' group-like delimited fields) by type name, `[extension.name]`;
  - an `Any` written as `[type.url/pkg.Type] { … }`. Whitespace, comments and percent escapes in bracketed names are
    accepted; an invalid escape is refused.

  It refuses what C++ refuses: a field given twice, two oneof members, a closed enumeration's unknown number, a missing
  required field, hex or octal for a float. Reserved names are skipped. Writing puts one field per line, and unknown fields
  print by number on request (a payload that reads as fields as `n { … }`, as C++ prints it). Parsing and printing are
  iterative.
- Conformance, the testee answering everything but JSPB through dynamic messages:
  - **binary and JSON: 5,647 passed, 0 failed** (2 skipped, JSPB);
  - **text format: 909 passed, 0 failed**.

  The failure list is empty.
- Generated differential: `Scripts/generated-differential.py` writes 120 seeded random messages of the proto3 and proto2
  test types (every scalar kind, repeated, packed and unpacked, maps, oneofs, enumerations, nesting to depth 3, groups), and
  protoc encodes them. Each reads as text and as binary to protoc's bytes (`GeneratedDifferentialTests`). The generator writes
  each map key once, because protoc's text path keeps duplicate keys where a reader keeps the last.
