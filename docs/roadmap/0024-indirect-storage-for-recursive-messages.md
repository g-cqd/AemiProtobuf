---
status: not-started
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
