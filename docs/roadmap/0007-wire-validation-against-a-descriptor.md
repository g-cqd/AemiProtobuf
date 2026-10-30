---
status: done
blocked-by: []
date: 2026-10-25
---

# 0007 — Wire validation against a descriptor

Scope: `validate(bytes, against:)`, strict: wire type per field, UTF-8, packed and unpacked repeated, required, nesting and size limits, with the path of the first error. Returns all findings up to a cap, not only the first.

Oracle: `protoc --decode` accepts or refuses the same bytes against the same `.proto`.

## Done

Top-level and nested validation: wire type per field, UTF-8, packed framing, required fields, duplicate and illegal descriptor
numbers, and a finding cap that holds across messages. `validate(bytes:against:in:)` resolves each message-typed field's type in a
`FileDescriptorSet` (`SchemaIndex`: fully qualified names, and the innermost-scope-outward rule for relative ones), checks nested
messages with an explicit queue (no recursion; depth bounded by `limits.maxDepth`), and reports each finding with the path of
fields to its message (`items[1].deep`). Offsets are those of the whole buffer. Tests: protoc bytes for a nested message have no
findings; paths, ordering, a malformed packed run in a nested message, relative-name resolution, an unresolved type, a 2,000-deep
chain, the cap, nested `required`. Fuzzed: every one-byte change and every prefix.

## Open

- A `protoc --decode` differential corpus of accepted and refused bytes (the oracle for the refusing side).
- Groups, proto2 closed enums, and extensions.
- A benchmark of nested validation, and mutation coverage of the schema target.

## Done (2026-10-30)

- Groups: a group field's body (`WireReader.readGroupRange`) is queued and checked as the message it holds, with its path.
- Extensions: the extensions a set declares for a message are checked as its fields; in strict mode a number inside the message's
  extension ranges is not an unknown field.
- Closed enumerations (proto2, or `enum_type = CLOSED`): in strict mode a number with no value is `unknownEnumValue`, singular and
  packed. C++ keeps such a number as an unknown field, so the lenient mode (the default) accepts it.
- The oracle for the refusing side: `Scripts/validator-corpus.py` writes 868 mutations (every byte replaced three ways, every
  truncation) of protoc-written proto3 and proto2 messages with `protoc --decode`'s verdict. Everything protoc refuses (577), the
  validator refuses. Of what protoc accepts, the validator refuses 22, each for a documented reason: a declared field with another
  wire type, a missing required field (`protoc --decode` parses partially), the varint and tag forms of ADR-0003.
- Benchmark `Schema.validateNested100` (100 nested messages: 99 µs, 222 allocations), on the allocation gate.

Not done: mutation coverage of the schema target (the mutation gate runs on the core; extending it is with the deferred CI work).
