# Models

Formal models of the wire core. `Scripts/model.sh` runs all of them; ADR-0007 says what each one is and is not.

| Path | Tool | What it holds |
|---|---|---|
| `lean/AemiProtobufModels/ZigZag.lean` | Lean 4 (`bv_decide`) | zig-zag is a bijection on 32 and 64 bits; small values take one byte |
| `lean/AemiProtobufModels/Varint.lean` | Lean 4 | varint round trip, length, byte range, ten-byte bound, for every natural number |
| `tla/GroupSkip.tla` | TLA+ / TLC | the group-skipping loop: bounded stack, termination, agreement with a stack-free definition |

The Swift test `WireGroupSkipExhaustiveTests` runs the real reader against the same definition (`GroupOracle`), so a model that
holds and code that disagrees cannot both pass.

## Adding a model

1. Write the property as an invariant or a theorem, and name the Swift code it is about in the header.
2. Break it on purpose (a one-character mutation) and watch the tool reject it, before trusting a pass.
3. Pair it with a test that runs the code against the same oracle.
4. For a type with an `await` or a lock, `modeler check Sources` finds the gap, and
   `modeler tla Sources --type T --output Models/tla/generated` writes a module and configuration for TLC. The model is an
   over-approximation: a trace shows a schedule the code can follow, and a pass does not prove the code correct.

TLC needs Java and the jar that `Scripts/tools.sh install tla2tools` fetches. Lean needs elan, installed separately (`lean-toolchain` pins 4.35.0).
