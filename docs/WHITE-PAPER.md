# AemiProtobuf — Project White Paper

The rules this project runs on. Principles live here and never a log: the log is the diary. The same evidence rule, safety
rule and documentation law bind `aemiregex`, `AemiJSON` and the Aemi kernel; this file states them for the wire format.

## What this is

A Protocol Buffers library for Swift for high-performance API communication. It does for the protobuf wire format what AemiJSON
does for JSON, and the surface follows AemiJSON on purpose:

| AemiJSON | AemiProtobuf (planned, `docs/DESIGN.md`) |
|---|---|
| `AemiJSONCore`: tape, `JSON`, cursor | `AemiProtobufCore`: wire reader and writer (built), lazy message view, descriptors |
| `JSONDecoder` / `JSONEncoder` (Codable) | `ProtobufDecoder` / `ProtobufEncoder` (Codable) |
| `@JSONCodable` fast path | `@ProtoMessage` fast path |
| `@Schemable`, `JSONSchema`, validate, infer | descriptors, `@ProtoMessage` schema, `.proto` text, wire validation, breaking-change check |
| `JSONEventReader`, async sequences | frame readers: gRPC 5-byte frames, varint-delimited streams |
| `AemiJSONNIO` | `AemiProtobufNIO` |

The test for living in this package and not in a consumer is whether a second consumer is plausible: any server or client that
talks protobuf, gRPC or Connect, and any tool that checks a `.proto`.

## The evidence rule

Every claim is named, given a probe that could fail, run, and recorded in the diary before it is acted on.

- **A probe that cannot fail is not a probe.** A comparison that is not fair is worse than none.
- **A test that has never failed proves nothing.** A new gate is broken on purpose once, to prove it fires. The wire core's tests
  were checked against 14 mutants (diary 2026-10-25-01).
- **Unprobed claims are written as open questions, never as facts.** What swift-protobuf does internally, what the reverse writer
  would cost, and what a borrowed string view would gain are open until a probe says.

## Safety is the first goal and a property of the algorithm

Order of goals: correctness, then safety, then speed. Speed never buys back either.

**Input is attacker input.** Every read is bounds-checked and returns a typed `WireError` with the offset. Nothing traps on any
byte sequence, reads past the buffer, or loops without consuming. A fuzz-style test and a differential test against `protoc` pin this.

**Every cost has a limit.** Nesting depth (default 100), message size (default 2^31-1), and every length prefix against the bytes
that remain. A limit is a typed error, never an allocation the input chose.

**No recursion in the engine.** Group skipping uses an explicit, depth-bounded stack. A nested message is read through a closure
whose depth the reader counts (`readMessage`); the Codable and fast paths are recursive by nature, so they carry the same
`maxDepth` and fail closed, as AemiJSON's `maxDecodingDepth` does.

**Strict by default, and the differences from `protoc` are listed** (ADR-0003). A parser difference between two implementations is
a security problem, so the default refuses what the reference truncates silently.

**`unsafe` is confined.** The one raw buffer is private to a `@safe` type, every access is checked against `end`, and `end` is
bounded by the buffer at construction (ADR-0002). No `-Ounchecked`, no disabled checks.

## Speed is a number

Every change that can affect performance is benchmarked, before and after, same harness, release build, median and spread. The
comparison is with swift-protobuf, the incumbent, on a frozen corpus, and later with a Rust and a C++ implementation. Until a
frozen harness exists (roadmap 0012), a speed statement is an indication, labelled as one. Debug builds measure a program nobody
ships, so no benchmark runs in debug.

## Compliance is measured against an oracle

`protoc` 36.2 is the oracle: `--encode` and `--decode_raw` for bytes, `--descriptor_set_out` for descriptors. Expected values come
from the oracle, not from the author, and are stored as fixtures with the script that made them. A divergence is recorded with the
oracle's answer. The official conformance runner is the later, wider oracle (roadmap 0011).

## Dependencies

`AemiKernel` and `AemiKernels` (varint append, little-endian loads, SIMD UTF-8 validation), pinned to the revision AemiJSON pins.
No Foundation in the engine. Anything else is an ADR with the alternatives compared. swift-protobuf is a benchmark and oracle
peer, never a dependency.

## Documentation law

| Path | Rule |
|---|---|
| `docs/WHITE-PAPER.md` | Principles, never a log. Capped at 200 lines. |
| `docs/adr/NNNN-title.md` | One decision per file, `accepted` or `superseded`. A decision changed by evidence becomes a new ADR that supersedes the old. |
| `docs/roadmap/NNNN-title.md` | One claimable unit of work per file with `status:` and `blocked-by:`. |
| `docs/diary/YYYY-MM-DD-NN.md` | The working log and the probe history. 256 lines; roll over. |

`docs/research/` holds dated notes and probe sources. `docs/DESIGN.md` describes the architecture. `DocumentationLayoutTests` enforces this table (ADR-0006).

## Quality gates

One entry point (`Scripts/quality.sh`), pinned tools (`Scripts/tools.lock`), no shared workflow (ADR-0006, ADR-0007). Format,
SwiftLint metrics, deadwood, dolly, arcleak, fcheck, `modeler check`, the suite in debug and release, the Lean proofs and TLA+
models, and the allocation thresholds run before a push; mutation testing runs on its own schedule. Every gate is made to fail on
purpose once before it is trusted.

## Process

Test first, and see it fail for the right reason. Mutation against a proven-green baseline, restored from a copy and never with
`git checkout`. Atomic commits that say why. A pre-existing problem found on the way is a roadmap entry, not a silent repair.
