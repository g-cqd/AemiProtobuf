---
status: done
blocked-by: []
date: 2026-10-29
---

# 0024 — Recursive messages

The conformance messages hold themselves (`TestAllTypesProto3.recursive_message`, `NestedMessage.corecursive`), as do trees in
real schemas. A struct cannot hold itself by value, and the macro refuses classes.

Scope: a field type the macro accepts for a message that contains itself, directly or through another (a copy-on-write box, e.g.
`@ProtoField(n) var child: Indirect<T>?`, or the macro boxing an `indirect` annotated field); decode bounded by `limits.maxDepth`
without recursion on the encode side's size computation either (the repository's no-recursion gate applies to the library).
Red: a 1,000-deep chain round trip, a depth over the limit refused, value semantics on mutation of a copy.

## Done

`@Indirect`, a property wrapper over a copy-on-write box: `@ProtoField(2) @Indirect var child: Node? = nil`. The macro needed no
change; the memberwise initializer still takes `child: Node?`. `Equatable`, `Hashable` and `Sendable` follow the value; `Codable`
encodes the value in place, and `KeyedDecodingContainer`/`KeyedEncodingContainer` overloads make an absent or `nil` optional
`@Indirect` field behave as a plain `Optional` property. Red `bc8b291` (value semantics and the generic coders failed against a
shared box). Depth: a chain under `maxDepth` round-trips, one past it is refused encoding and decoding, and a larger limit admits
it. The generated encoder recurses, as every nested message does, bounded by `maxDepth`; the library's own code does not.
