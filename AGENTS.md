# Working in `AemiProtobuf`

A Protocol Buffers library for Swift, shaped like AemiJSON. **Read [`docs/WHITE-PAPER.md`](docs/WHITE-PAPER.md) first**: it carries the
principles and leads with the evidence rule. `docs/DESIGN.md` is the architecture and its open questions; `docs/roadmap/` is the work.

## Commands

```sh
Scripts/quality.sh fast                                        # format, SwiftLint, deadwood, dolly, arcleak, fcheck, modeler (~10 s)
Scripts/quality.sh test                                        # debug (bounds checks live), then release (what ships)
Scripts/quality.sh model                                       # Lean proofs, TLA+ models under TLC, modeler (~20 s)
Scripts/quality.sh bench                                       # allocation thresholds, then the benchmark report (release)
Scripts/quality.sh all                                         # fast + test + model + bench; what the pre-push hook and CI run
Scripts/quality.sh mutation                                    # swift-mutation-testing at the experimental tier (~9 min)
Scripts/compare.sh all                                         # AemiJSON against AemiProtobuf on the same data: check, ~10 min benchmark, report (Benchmarks/Comparison)
Scripts/tools.sh install                                       # install or build the pinned tools (Scripts/tools.lock) into the cache
swift-format format -i -r Sources Tests Benchmarks Package.swift   # apply formatting
python3 Scripts/golden/decode-raw-verdicts.py > Tests/AemiProtobufCoreTests/Resources/decode-raw-verdicts.jsonl   # needs protoc
git config core.hooksPath .githooks                            # once per clone: pre-commit runs fast, pre-push runs all
```

## Gates

- **`Scripts/quality.sh`** (ADR-0006, ADR-0007): `swift-format lint --strict` (style), SwiftLint (`only_rules`, metrics only),
  deadwood, dolly, arcleak, fcheck (`--strict`), `modeler check`, Lean (`lake build --wfail`, no `sorry`), TLC on every
  `Models/tla/*.cfg`, allocation thresholds (`Benchmarks/Thresholds`), and `swift-mutation-testing` against
  `.swift-mutation-testing-baseline.json`.
- **`AemiProtobufRepositoryTests`**: `SourceStructureTests` (one type per file, 250 lines), `NoRecursionTests` (no function reaches
  itself, in sources, tests, benchmarks or scripts), `DocumentationLayoutTests` (the white paper's document law),
  `RepositoryHygieneTests` (no build output, large file, home-directory path, token or work marker is tracked). Kept in its own
  target because mutation testing copies `AemiProtobufCoreTests` to a sandbox where `#filePath` and `git` do not see the repository.

## Traps

- **The comparison is its own package** (`Benchmarks/Comparison`, needs the AemiJSON checkout next to this one) because the two libraries must pin one Aemi revision. Run it through `Scripts/compare.sh`; `swift build` of its suite target fails to link by design, the benchmark plugin supplies the entry point.
- **The benchmark plugin only sees executable targets under a `Benchmarks/` directory.**
- **Write messages with `@ProtoMessage` + `@ProtoField(n)`** (ADR-0011). The generated code names core types, so `AemiProtobuf` re-exports `AemiProtobufCore`. Macro tests use `SwiftSyntaxMacrosGenericTestSupport` with a failure handler for Swift Testing, because `assertMacroExpansion` otherwise reports to XCTest.
- **`Codable` has no schema.** Swift types map to wire types by container (ADR-0010); `sint`/`fixed`/`map`/`oneof` need the fast path.

- **Typed throws and `#expect`.** `#expect(try read(...) { ... })` fails to compile: `#expect` throws `any Error`, the reader closure
  throws `WireError`. Bind the result first. Write `r throws(WireError) in`; `$0` does not infer it.
- **`Array.withUnsafeBytes` rethrows `any Error`,** so the typed error crosses it inside a `Result`.
- **`Array.span` needs macOS 26.** The floor is 15 (ADR-0002).
- **`InternalImportsByDefault`:** a public `@inlinable` function cannot call into `AemiKernel`.
- **Benchmark names must not contain spaces or colons.** The Benchmark tool splits on `:` when it looks up a threshold file, so a
  name like `"Users: write"` never matches its own file. Use `Users1000.write`.
- **Wall clock is never a gate.** A median moved 220 to 297 µs across two runs here. `AEMIPROTOBUF_BENCH_GATE=1` measures
  allocations only, which are exact.
- **Accept a static-analyzer finding where it is, with a reason** (`// @dl:accept -- why`, `// @fc:accept rule -- why`), never silently.
- **`protoc` is lenient in two places** the reader is not (ADR-0003). A new disagreement in the verdict test is a finding, not noise.

## Dependencies

`AemiKernel`, `AemiKernels` from the Aemi package, pinned to the revision AemiJSON pins. Nothing else in the shipped targets;
`ordo-one/benchmark` is gated behind `AEMIPROTOBUF_DEV`.
