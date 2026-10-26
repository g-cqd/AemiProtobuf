---
status: accepted
date: 2026-10-25
---

# 0006 — Standalone quality gates: one entry point, pinned tools, no shared workflow

## Context

`aemiregex` borrows its lint plugin, its format plugin and its CI legs from the Aemi package. This repository is standalone: a
clone must be able to run every gate with nothing but this repository, a Swift toolchain, and the pinned tools. The request also
named the tools to build in: arcleak, dolly, deadwood, modeler, fcheck, swift-mutation-testing, benchmarks, SwiftLint, swift-format.

## Decision

`Scripts/quality.sh <gate>` is the only entry point. The git hooks and the CI jobs call it, so a gate cannot differ between a
developer machine and CI.

| Gate | Tool | What it holds |
|---|---|---|
| `format` | `swift-format lint --strict` (the toolchain's, `.swift-format`) | style; the only style authority |
| `lint` | SwiftLint (`.swiftlint.yml`, `only_rules`) | size and complexity metrics swift-format cannot express; no style rule can fight swift-format |
| `analyzers` | deadwood, dolly, arcleak, fcheck, `modeler check` | unused code, clones, retain cycles, obligations on every path out of a function, check-then-write gaps |
| `test` | `swift test`, debug then release | behaviour; debug keeps the unsafe-pointer bounds checks live, release is what ships |
| `model` | Lean 4, TLC, modeler | ADR-0007 |
| `bench` | ordo-one `package-benchmark` | allocation thresholds (exact), wall clock (reported only) |
| `mutation` | swift-mutation-testing | whether the tests can fail (ADR-0007) |

Four gates are Swift tests in their own target, `AemiProtobufRepositoryTests` (ported from `aemiregex`): one top-level type per
file and a 250-line cap; no function reaches itself (no recursion, in sources, tests and scripts); documents follow the layout law
in the white paper; nothing tracked that must not be published (build output, a home path, a token, a work marker). They read the
working tree and run `git`, so they live apart from `AemiProtobufCoreTests`, the target mutation testing copies to a sandbox.

`Scripts/tools.lock` pins every tool: release archives by version and per-platform SHA-256, checked before anything runs;
fcheck and modeler, which publish no archive, by commit (built once, about eight minutes, then cached); TLC by version and SHA-256.
The cache lives outside the repository.

## Evidence

Each gate was made to fail on purpose before it was trusted (diary 2026-10-25-02):

- the four ported tests, run on this repository, found a second type in `WireSupport.swift` and a home-directory path in a probe
  record that I had committed to the docs;
- planted code made deadwood (unused type and function), arcleak (stored-closure retain cycle), fcheck (a descriptor leaked when a
  later `try` throws) and modeler (a check, an `await`, then a write on an actor) each report;
- Lean proofs and a TLA+ model each reject a one-character mutation; the allocation threshold rejects a removed `reserveCapacity`.

On the current sources: swift-format 0 findings after formatting, SwiftLint 0 violations, deadwood 0, arcleak 0, fcheck 0,
modeler 0, dolly 8 notes in test code (notes never fail `--strict`).

## Consequences

- The Aemi plugins (`Format`, `Lint`, `LintBuild`) are not used, so their extra bans (force unwrap, wall-clock) are not enforced by
  tool. The force-unwrap rule is a project rule that review enforces, until a gate does (roadmap 0013).
- Linux is not verified. The scripts and the workflow are written for it, but nothing ran there. The first CI run is expected to
  need changes; the workflow says so.
- fcheck and modeler built from source make a cold CI run slow. Asking for release archives is roadmap 0015.
