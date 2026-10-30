#!/usr/bin/env python3
"""Roadmap 0006: the oracle for DynamicMessage. protoc (36.2) encodes text messages of the conformance test types with
--deterministic_output (fields in number order, maps by key); a `merge` case decodes the concatenation of two encodings and
encodes it again, so the expected bytes are protoc's merge. Writes Tests/AemiProtobufSchemaTests/Resources/dynamic/cases.json:
[{"name", "type", "input" (hex), "expected" (hex)}]. Run from the repository root with PROTOBUF_SOURCE set."""
import json, os, subprocess, sys

SOURCE = os.environ.get('PROTOBUF_SOURCE', '/Volumes/Personal/build/protobuf')
INCLUDES = [f'-I{SOURCE}/src', f'-I{SOURCE}']
FILES = {
    'protobuf_test_messages.proto3.TestAllTypesProto3': 'google/protobuf/test_messages_proto3.proto',
    'protobuf_test_messages.proto2.TestAllTypesProto2': 'google/protobuf/test_messages_proto2.proto',
    'protobuf_test_messages.editions.proto2.TestAllTypesProto2': 'editions/golden/test_messages_proto2_editions.proto',
    'protobuf_test_messages.editions.proto3.TestAllTypesProto3': 'editions/golden/test_messages_proto3_editions.proto',
}
P3, P2 = 'protobuf_test_messages.proto3.TestAllTypesProto3', 'protobuf_test_messages.proto2.TestAllTypesProto2'
E2, E3 = 'protobuf_test_messages.editions.proto2.TestAllTypesProto2', 'protobuf_test_messages.editions.proto3.TestAllTypesProto3'

SCALARS = '''optional_int32: -5 optional_int64: -9000000000 optional_uint32: 4000000000 optional_uint64: 18000000000000000000
optional_sint32: -77 optional_sint64: -88888888888 optional_fixed32: 123 optional_fixed64: 456 optional_sfixed32: -9
optional_sfixed64: -10 optional_float: 1.5 optional_double: -2.25 optional_bool: true optional_string: "héllo"
optional_bytes: "\\000\\377" optional_nested_enum: BAZ optional_foreign_enum: FOREIGN_BAR'''
REPEATED = '''repeated_int32: [1, -2, 300] repeated_sint64: [-1, 1] repeated_fixed32: [7, 8] repeated_double: [0.5, -0.0]
repeated_bool: [true, false] repeated_string: ["a", "", "ç"] repeated_bytes: ["x", ""] repeated_nested_enum: [FOO, BAR]
repeated_nested_message: [{a: 1}, {}, {a: 3}]'''
PACKING = '''packed_int32: [1, 2] packed_double: [1.0] packed_nested_enum: [BAZ] unpacked_int32: [3, 4] unpacked_float: [2.5]
unpacked_nested_enum: [FOO]'''
MAPS = '''map_int32_int32 {key: 2 value: 20} map_int32_int32 {key: 1 value: 10} map_string_string {key: "b" value: ""}
map_string_string {key: "a" value: "x"} map_bool_bool {key: true value: false} map_string_nested_message {key: "m" value {a: 9}}
map_string_nested_message {key: "e" value {}} map_int64_int64 {key: -1 value: 0} map_string_foreign_enum {key: "f" value: FOREIGN_BAZ}'''
NESTED = '''optional_nested_message {a: 1 corecursive {optional_int32: 2 recursive_message {optional_string: "deep"
optional_nested_message {corecursive {repeated_int32: [5]}}}}} recursive_message {optional_bool: true}'''

CASES = [
    ('proto3-scalars', P3, SCALARS), ('proto3-defaults-are-omitted', P3, 'optional_int32: 0 optional_string: "" optional_bool: false'),
    ('proto3-negative-zero-is-kept', P3, 'optional_double: -0.0 optional_float: -0.0'),
    ('proto3-optional-zero-is-kept', P3, 'optional_nested_message {}'),
    ('proto3-repeated', P3, REPEATED), ('proto3-packing', P3, PACKING), ('proto3-maps', P3, MAPS), ('proto3-nested', P3, NESTED),
    ('proto3-oneof-message', P3, 'oneof_nested_message {a: 4}'), ('proto3-oneof-empty-string', P3, 'oneof_string: ""'),
    ('proto3-wellknown', P3, 'optional_timestamp {seconds: 5 nanos: 6} optional_any {type_url: "t" value: "v"} optional_int32_wrapper {}'),
    ('proto2-scalars', P2, SCALARS), ('proto2-zeros-are-kept', P2, 'optional_int32: 0 optional_string: "" optional_bool: false'),
    ('proto2-repeated', P2, REPEATED), ('proto2-packing', P2, PACKING), ('proto2-maps', P2, MAPS), ('proto2-nested', P2, NESTED),
    ('proto2-groups', P2, 'data {group_int32: 1 group_uint32: 2} multiwordgroupfield {group_int32: 3}'),
    ('proto2-defaults-written-when-set', P2, 'default_int32: -123456789 default_string: "Rosebud"'),
    ('editions2-scalars', E2, SCALARS), ('editions2-delimited', E2, 'data {group_int32: 1} multiwordgroupfield {group_uint32: 7}'),
    ('editions2-packing', E2, PACKING), ('editions3-scalars', E3, SCALARS), ('editions3-maps', E3, MAPS),
    ('editions3-defaults-are-omitted', E3, 'optional_int32: 0 optional_bool: false'),
]
MERGES = [
    ('merge-proto3-nested', P3, 'optional_nested_message {a: 1 corecursive {optional_int32: 1 optional_string: "x"}} repeated_int32: [1] optional_int32: 1',
     'optional_nested_message {corecursive {optional_int32: 2 repeated_int32: [3]}} repeated_int32: [2] optional_int32: 2'),
    ('merge-proto3-maps-last-key-wins', P3, 'map_int32_int32 {key: 1 value: 1} map_string_nested_message {key: "k" value {a: 1}}',
     'map_int32_int32 {key: 1 value: 2} map_string_nested_message {key: "k" value {corecursive {}}}'),
    ('merge-proto3-oneof-last-wins', P3, 'oneof_nested_message {a: 1}', 'oneof_uint32: 7'),
    ('merge-proto3-oneof-message-merges', P3, 'oneof_nested_message {a: 1}', 'oneof_nested_message {corecursive {optional_int32: 2}}'),
    ('merge-proto3-oneof-replaced-then-back', P3, 'oneof_nested_message {a: 1}', 'oneof_string: "s"', 'oneof_nested_message {corecursive {}}'),
    ('merge-proto2-groups', P2, 'data {group_int32: 1}', 'data {group_uint32: 2}'),
    ('merge-editions2-delimited', E2, 'data {group_int32: 1} recursive_message {optional_int32: 4}', 'data {group_uint32: 2} recursive_message {optional_bool: true}'),
]

def protoc(args, data):
    return subprocess.run(['protoc', *INCLUDES, *args], input=data, capture_output=True, check=True).stdout

def encode(type_name, text):
    return protoc([f'--encode={type_name}', '--deterministic_output', FILES[type_name]], text.encode())

out = []
for name, type_name, text in CASES:
    data = encode(type_name, text)
    out.append({'name': name, 'type': type_name, 'input': data.hex(), 'expected': data.hex()})
for name, type_name, *parts in MERGES:
    joined = b''.join(encode(type_name, part) for part in parts)
    decoded = protoc([f'--decode={type_name}', FILES[type_name]], joined)
    out.append({'name': name, 'type': type_name, 'input': joined.hex(), 'expected': encode(type_name, decoded.decode()).hex()})
path = 'Tests/AemiProtobufSchemaTests/Resources/dynamic/cases.json'
os.makedirs(os.path.dirname(path), exist_ok=True)
json.dump(out, open(path, 'w'), indent=1)
print(f'{len(out)} cases -> {path}')
