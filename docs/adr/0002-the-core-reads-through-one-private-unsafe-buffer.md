---
status: accepted
date: 2026-10-25
---

# 0002 — The core reads through one private unsafe buffer, behind a `@safe` type

## Context

The deployment floor is macOS 15 (as AemiJSON and Aemi). `WireReader` needs a borrowed, bounds-checked view of the input.

## Evidence

Probe, `swiftc -target arm64-apple-macosx15.0` on `let s = array.span`: `error: 'span' is only available in macOS 26.0 or newer`.
`RawSpan(_unsafeBytes:)` compiles at 15 (the type back-deploys; the `Array.span` accessor does not). The same trap is recorded in
`aemiregex/AGENTS.md`.

## Decision

`WireReader` is `@safe` and stores a private `UnsafeRawBufferPointer`. Invariants, each tested: `offset <= end <= buffer.count`;
`init` rejects a buffer over `maxMessageBytes`; a nested reader's range lies inside its parent's. Entry points take `[UInt8]` and
`RawSpan` safely, and a `@unsafe` pointer entry for `Data` and network buffers. Strings are validated by the SIMD kernel in
`AemiKernels` before `String(decoding:)`, so nothing is repaired.

Moving to `Span` when the floor reaches 26 changes the wrapper, not the engine.

## Consequences

A public `@inlinable` method cannot call into `AemiKernel` (`InternalImportsByDefault`), so the writer's `appendVarint` is not
inlinable across modules. Whether that costs anything in the macro-generated code is open; roadmap 0003 measures it and decides
between a local inlinable varint loop and `public import`.
