#!/usr/bin/env python3
"""Roadmap 0002: the oracle for the .proto compiler. Copies each root .proto and its imports into
Tests/AemiProtobufSchemaTests/Resources/parser/src, and writes protoc's descriptor set for it (--include_imports) to
parser/expected/<root with / as _>.pb. The fixtures under parser/src/fixtures are kept as they are. Run from the repository root
with PROTOBUF_SOURCE set (a checkout at the tag of the installed protoc)."""
import os, shutil, subprocess

SOURCE = os.environ.get('PROTOBUF_SOURCE', '/Volumes/Personal/build/protobuf')
BASE = 'Tests/AemiProtobufSchemaTests/Resources/parser'
WKT = ['any', 'api', 'duration', 'empty', 'field_mask', 'source_context', 'struct', 'timestamp', 'type', 'wrappers', 'descriptor']
ROOTS = [f'google/protobuf/{name}.proto' for name in WKT] + [
    'google/protobuf/test_messages_proto3.proto', 'google/protobuf/test_messages_proto2.proto',
    'editions/golden/test_messages_proto2_editions.proto', 'editions/golden/test_messages_proto3_editions.proto',
    'conformance/test_protos/test_messages_edition2023.proto', 'conformance/conformance.proto',
    'fixtures/kitchen.proto', 'fixtures/modern.proto', 'fixtures/edition.proto',
]
LOOKUP = [f'{SOURCE}/src', SOURCE, f'{BASE}/src']

os.makedirs(f'{BASE}/expected', exist_ok=True)
for root in ROOTS:
    out = f'{BASE}/expected/{root.replace("/", "_").removesuffix(".proto")}.pb'
    includes = [f'-I{BASE}/src'] + [f'-I{path}' for path in LOOKUP[:2]]
    subprocess.run(['protoc', *includes, '--include_imports', f'--descriptor_set_out={out}', root], check=True)
    # Copy every file the set names, so the compiler reads the same sources protoc read.
    listing = subprocess.run(['protoc', f'-I{SOURCE}/src', 'google/protobuf/descriptor.proto',
                              '--decode=google.protobuf.FileDescriptorSet'], stdin=open(out, 'rb'), capture_output=True,
                             text=True, check=True).stdout
    for line in listing.splitlines():
        if line.startswith('  name: "'):
            name = line.split('"')[1]
            target = f'{BASE}/src/{name}'
            if os.path.exists(target):
                continue
            for directory in LOOKUP:
                if os.path.exists(f'{directory}/{name}'):
                    os.makedirs(os.path.dirname(target), exist_ok=True)
                    shutil.copy(f'{directory}/{name}', target)
                    break
print(f'{len(ROOTS)} roots -> {BASE}')
