#!/usr/bin/env python3
"""Writes the validator's differential corpus (roadmap 0007): mutations of protoc-written messages, each with protoc's verdict.

    python3 Scripts/validator-corpus.py      rewrites Tests/AemiProtobufSchemaTests/Resources/differential.txt

Each line is `<message> <hex bytes> <accept|refuse>`, the verdict of `protoc --decode=<message>` on those bytes. The inputs are
every single-byte substitution (00, FF, and the byte with its top bit flipped) and every truncation of the base messages.
"""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = os.path.join(ROOT, "Tests/AemiProtobufTests/Resources")
OUT = os.path.join(ROOT, "Tests/AemiProtobufSchemaTests/Resources/differential.txt")
BASES = [("kinds.proto", "Kinds", "kinds.bin"), ("proto2.proto", "GroupHolder", "groups.bin"),
         ("proto2.proto", "Required", "required.bin")]


def verdict(proto, message, data):
    run = subprocess.run(["protoc", "-I", SOURCES, f"--decode={message}", proto], input=data, capture_output=True)
    return "accept" if run.returncode == 0 else "refuse"


lines = []
for proto, message, name in BASES:
    base = open(os.path.join(SOURCES, name), "rb").read()
    inputs = {base}
    for i in range(len(base)):
        for value in (0x00, 0xFF, base[i] ^ 0x80):
            inputs.add(base[:i] + bytes([value]) + base[i + 1:])
        inputs.add(base[:i])
    for data in sorted(inputs):
        lines.append(f"{message} {data.hex() or '-'} {verdict(proto, message, data)}")
open(OUT, "w").write("\n".join(lines) + "\n")
print(f"{len(lines)} inputs, {sum(l.endswith('refuse') for l in lines)} refused by protoc", file=sys.stderr)
