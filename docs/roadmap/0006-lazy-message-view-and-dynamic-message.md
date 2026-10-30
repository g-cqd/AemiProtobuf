---
status: done
blocked-by: []
date: 2026-10-25
---

# 0006 — Lazy message view and dynamic message

Scope: `ProtoMessage` over borrowed bytes, indexed once, nil-safe navigation by field number; borrowed string and bytes accessors that make no `String`; `DynamicMessage` over a descriptor.

Probe first (open question 3): decode reading half the fields of the 1,000-user corpus, through the view and through full materialization.

## Done (2026-10-30)

- `DynamicMessage`, `DynamicValue`, `DynamicSchema` (AemiProtobufSchema). Field semantics are resolved once per field from the
  edition features in force (`ResolvedFeatures`, moved here from the generator): presence, packing, delimited encoding, closed
  enumerations, UTF-8 checking, maps and real oneofs. Decoding is iterative: a FIFO of byte ranges, one node per nested message,
  merge by reusing a singular field's node, folded last-first. Encoding is iterative too: a stack of open messages with
  `beginMessage` / `endMessage`, fields in number order, map entries by key, unknown fields last.
- Oracle: 32 protoc-encoded cases (`Scripts/dynamic-corpus.py`) over the conformance types (proto3, proto2, both editions
  goldens), merges included. Every case round-trips to protoc's `--deterministic_output` bytes. protoc's `--decode` keeps
  duplicate map keys, so the map merge case states its expected message (the last entry wins).
- Edges: unknown fields, a known field with another wire type, closed and open enumerations, UTF-8 in proto3 and proto2,
  required fields, 101 levels refused at the default limit, 1,000 levels with a raised limit (no recursion), and values that do
  not fit the descriptor. The fuzz entry round-trips dynamic messages too (not run: see 0013).
- `ProtoMessageView` (AemiProtobufCore): bytes indexed once, fields by number (last occurrence wins), `nil` when absent or
  mistyped, nested views over the same array, `withBytes` / `utf8Equals` with no copy, `varints` across packed and unpacked.
- Probe: `docs/research/2026-10-30-lazy-view-probe.md`. The view reads half the corpus's fields in 507 µs against 771 µs for
  a full decode. The dynamic message decodes the corpus in 3.06 ms (from 6.37 ms in its first version).

Not done: extensions are read as unknown fields, and a `string` that need not be UTF-8 and is not is kept as `.bytes`.
