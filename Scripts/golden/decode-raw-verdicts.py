#!/usr/bin/env python3
"""Records whether `protoc --decode_raw` accepts each of a set of seeded, mutated wire buffers.

Output: one JSON object per line, {"hex": "...", "protoc": true|false}, on stdout. The expected value comes from protoc, not
from this repository. Usage: Scripts/golden/decode-raw-verdicts.py > Tests/AemiProtobufCoreTests/Resources/decode-raw-verdicts.jsonl
"""
import json, random, subprocess, sys

SAMPLE = bytes.fromhex(
    "08960112036 16e6e1a0561406 22e6320 0129000000000000f83f32017832017 93a0d01ac02ffffffffffffffffff01"
    "42080a0173120163180748055109 00000000000000".replace(" ", ""))
rng = random.Random(0xA3E1)

def mutate(b: bytes) -> bytes:
    b = bytearray(b)
    kind = rng.randrange(6)
    if kind == 0 and b: b[rng.randrange(len(b))] = rng.randrange(256)
    elif kind == 1 and b: del b[rng.randrange(len(b)):]
    elif kind == 2: b.insert(rng.randrange(len(b) + 1), rng.randrange(256))
    elif kind == 3 and b: del b[rng.randrange(len(b))]
    elif kind == 4: b += bytes(rng.randrange(256) for _ in range(rng.randrange(1, 12)))
    else: return bytes(rng.randrange(256) for _ in range(rng.randrange(0, 24)))
    return bytes(b)

def accepts(b: bytes) -> bool:
    return subprocess.run(["protoc", "--decode_raw"], input=b, capture_output=True).returncode == 0

seen = set()
cases = [SAMPLE, b"", b"\x08\x01"]
while len(cases) < 1500:
    b = mutate(SAMPLE if rng.random() < 0.8 else mutate(SAMPLE))
    if b not in seen:
        seen.add(b); cases.append(b)
for b in cases:
    print(json.dumps({"hex": b.hex(), "protoc": accepts(b)}))
