---
status: not-started
blocked-by: [0002]
date: 2026-10-25
---

# 0006 — Lazy message view and dynamic message

Scope: `ProtoMessage` over borrowed bytes, indexed once, nil-safe navigation by field number; borrowed string and bytes accessors that make no `String`; `DynamicMessage` over a descriptor.

Probe first (open question 3): decode reading half the fields of the 1,000-user corpus, through the view and through full materialization.
