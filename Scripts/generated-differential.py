#!/usr/bin/env python3
"""Roadmap 0011: a seeded differential. Generates random text-format messages of the conformance test types (every scalar
kind, repeated and packed fields, maps, oneofs, enumerations, nested messages to depth 3, groups in proto2), has protoc (36.2)
encode each with --deterministic_output, and writes Tests/AemiProtobufSchemaTests/Resources/differential/cases.json:
[{"seed", "type", "text", "bytes" (hex)}]. The Swift side reads each text and each binary and must write protoc's bytes."""
import json, os, random, subprocess

SOURCE = os.environ.get('PROTOBUF_SOURCE', '/Volumes/Personal/build/protobuf')
TYPES = {
    'protobuf_test_messages.proto3.TestAllTypesProto3': 'google/protobuf/test_messages_proto3.proto',
    'protobuf_test_messages.proto2.TestAllTypesProto2': 'google/protobuf/test_messages_proto2.proto',
}
COUNT = 120

def scalar(rng, kind):
    if kind in ('int32', 'sint32', 'sfixed32'): return str(rng.choice([0, 1, -1, rng.randint(-2**31, 2**31 - 1)]))
    if kind in ('int64', 'sint64', 'sfixed64'): return str(rng.choice([0, -1, rng.randint(-2**63, 2**63 - 1)]))
    if kind in ('uint32', 'fixed32'): return str(rng.choice([0, 1, rng.randint(0, 2**32 - 1)]))
    if kind in ('uint64', 'fixed64'): return str(rng.choice([0, rng.randint(0, 2**64 - 1)]))
    if kind in ('float', 'double'): return rng.choice(['0', '-0.0', '1.5', '-2.25e10', 'inf', '-inf', repr(rng.uniform(-1e6, 1e6))])
    if kind == 'bool': return rng.choice(['true', 'false'])
    if kind == 'string': return json.dumps(''.join(rng.choice('abcé😀 \n"\\') for _ in range(rng.randint(0, 8))), ensure_ascii=False)
    if kind == 'bytes': return '"' + ''.join('\\%03o' % rng.randint(0, 255) for _ in range(rng.randint(0, 6))) + '"'
    if kind == 'nested_enum': return rng.choice(['FOO', 'BAR', 'BAZ', 'NEG'])
    if kind == 'foreign_enum': return rng.choice(['FOREIGN_FOO', 'FOREIGN_BAR', 'FOREIGN_BAZ'])
    raise ValueError(kind)

SCALARS = ['int32', 'int64', 'uint32', 'uint64', 'sint32', 'sint64', 'fixed32', 'fixed64', 'sfixed32', 'sfixed64', 'float',
           'double', 'bool', 'string', 'bytes']
MAPS = [('int32', 'int32'), ('int64', 'int64'), ('uint32', 'uint32'), ('sint64', 'sint64'), ('fixed32', 'fixed32'),
        ('bool', 'bool'), ('string', 'string'), ('string', 'bytes'), ('int32', 'double'), ('string', 'nested_enum')]
MAP_NAME = {'nested_enum': 'nested_enum'}

def message(rng, proto2, depth):
    parts = []
    for kind in SCALARS:
        if rng.random() < 0.35: parts.append(f'optional_{kind}: {scalar(rng, kind)}')
        if rng.random() < 0.2:
            parts += [f'repeated_{kind}: {scalar(rng, kind)}' for _ in range(rng.randint(1, 3))]
    for kind in ['int32', 'sint64', 'double', 'bool', 'fixed32']:
        if rng.random() < 0.15: parts += [f'packed_{kind}: {scalar(rng, kind)}' for _ in range(rng.randint(1, 3))]
        if rng.random() < 0.15: parts += [f'unpacked_{kind}: {scalar(rng, kind)}' for _ in range(rng.randint(1, 3))]
    if rng.random() < 0.3: parts.append(f'optional_nested_enum: {scalar(rng, "nested_enum")}')
    if rng.random() < 0.3: parts.append(f'optional_foreign_enum: {scalar(rng, "foreign_enum")}')
    for key, value in MAPS:
        if rng.random() < 0.15:
            name = f'map_{key}_{MAP_NAME.get(value, value)}'
            # One entry per key: protoc's text path keeps duplicate keys, where a reader keeps the last.
            keys = {scalar(rng, key) for _ in range(rng.randint(1, 3))}
            for written in sorted(keys):
                parts.append(f'{name} {{ key: {written} value: {scalar(rng, value)} }}')
    if rng.random() < 0.3: parts.append(f'optional_nested_message {{ a: {scalar(rng, "int32")} }}')
    if depth < 3 and rng.random() < 0.35:
        parts.append('recursive_message { ' + message(rng, proto2, depth + 1) + ' }')
    if rng.random() < 0.3:
        choice = rng.choice(['oneof_uint32: ' + scalar(rng, 'uint32'), 'oneof_string: ' + scalar(rng, 'string'),
                             'oneof_bool: ' + scalar(rng, 'bool'), 'oneof_nested_message { a: 3 }'])
        parts.append(choice)
    if proto2 and rng.random() < 0.3: parts.append(f'Data {{ group_int32: {scalar(rng, "int32")} }}')
    rng.shuffle(parts)
    return ' '.join(parts)

out = []
for seed in range(COUNT):
    rng = random.Random(seed)
    type_name = list(TYPES)[seed % 2]
    text = message(rng, 'proto2' in type_name, 0)
    encoded = subprocess.run(['protoc', f'-I{SOURCE}/src', f'--encode={type_name}', '--deterministic_output', TYPES[type_name]],
                             input=text.encode(), capture_output=True, check=True).stdout
    out.append({'seed': seed, 'type': type_name, 'text': text, 'bytes': encoded.hex()})
path = 'Tests/AemiProtobufSchemaTests/Resources/differential/cases.json'
os.makedirs(os.path.dirname(path), exist_ok=True)
json.dump(out, open(path, 'w'), indent=1, ensure_ascii=False)
print(f'{len(out)} cases -> {path}')
