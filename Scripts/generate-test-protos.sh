#!/bin/sh
# Regenerates Tests/AemiProtobufGeneratedTests/Generated*.swift and the descriptor sets the generator tests read, from the
# .proto files in Tests/AemiProtobufGeneratorTests/Resources, with protoc and the package's own protoc-gen-aemi.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
swift build --product protoc-gen-aemi
PLUGIN="$(swift build --show-bin-path)/protoc-gen-aemi"
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
cd Tests/AemiProtobufGeneratorTests/Resources
for proto in *.proto; do
    name=${proto%.proto}
    protoc -I. --descriptor_set_out="$name.pb" "$proto"
    protoc -I. --plugin=protoc-gen-aemi="$PLUGIN" --aemi_out="$OUT" "$proto"
    capitalized=$(printf '%s' "$name" | cut -c1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "$name" | cut -c2-)
    cp "$OUT/$name.aemi.swift" "$ROOT/Tests/AemiProtobufGeneratedTests/Generated$capitalized.swift"
done
