---
status: done
blocked-by: []
date: 2026-10-25
---

# 0010 — Proto3 JSON mapping

Scope: `AemiProtobufJSON` over `AemiJSONCore`: the canonical mapping (int64 as strings, bytes as base64, enums by name, well-known types, `null` and defaults), parse and print. Oracle: `protoc`-independent; the conformance runner (0011) covers it.

## Done (2026-10-30)

- `AemiProtobufJSON` (on AemiJSONCore, pinned at `fdc0143`, the aemi revision AemiProtobuf pins): `ProtoJSONCoder` over
  `DynamicSchema`. It reads and writes JSON, and transcodes JSON to and from binary. Options: ignore unknown fields, emit
  defaults, proto field names, maximum depth.
- The mapping:
  - lowerCamel names out, either form in; 64-bit integers as strings, read from numbers or strings exactly (`1e2`, `1.0`);
  - `NaN` / `Infinity` / `-Infinity`; base64 out in the standard alphabet, in from either alphabet;
  - enumerations by name or number; `null` as absent, except for `Value` and `NullValue`;
  - duplicate fields and second oneof members refused;
  - maps as objects with keys as strings;
  - extensions as `[full.name]`;
  - the well-known types: Any (`value` for the types with a JSON form, not for Empty, as C++), Timestamp, Duration, FieldMask,
    Struct, Value, ListValue, the wrappers and Empty.
- Reading and printing are iterative, like the binary path. Reading is a FIFO of JSON values with nodes folded last-first;
  `DynamicFields` is the assembly step shared with the binary decoder. Printing is a stack of pending output.
- Conformance: the testee answers JSON through the embedded descriptor set. **5,647 binary and JSON tests passed, 0 failed**
  (2 skipped: JSPB). The 909 text-format tests stay skipped (0011).
- Unit tests: 16 spec-driven cases. They include binary → JSON → binary over the 32-case dynamic corpus, and 1,000 levels of
  nesting.
- 1,000 users, release: encode 4.4 ms (27 mallocs), decode 6.1 ms (18 K mallocs). The first version took 14 ms and 9.3 ms;
  paths built only on errors, commas decided by the output and a bit mask for repeated members gave the difference.

Not done:
- A typed API inside this module: macro and generated types go through their binary form (see `ProtoJSONCoder`), so the
  module needs neither the macros nor Foundation.
- No comparison with swift-protobuf's JSON was measured.
