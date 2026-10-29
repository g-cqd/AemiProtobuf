#!/bin/sh
# Runs the official protobuf conformance suite against the generated testee (roadmap 0011).
#
#   PROTOBUF_SOURCE=/path/to/protobuf Scripts/conformance.sh            regenerate the testee's sources, build, run
#   PROTOC=/path/to/protoc                                               the protoc to generate with (default: on PATH)
#
# PROTOBUF_SOURCE is a checkout of github.com/protocolbuffers/protobuf at the tag of the installed protoc (36.2 here), with
# conformance_test_runner built in PROTOBUF_SOURCE/build:
#   cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -Dprotobuf_BUILD_CONFORMANCE=ON -Dprotobuf_BUILD_TESTS=OFF \
#         -Dprotobuf_ABSL_PROVIDER=package -Dprotobuf_BUILD_LIBUPB=OFF -DCMAKE_CXX_STANDARD=17
#   ninja -C build conformance_test_runner
# Every test that fails must be listed in Conformance/failure_list.txt with its reason; the runner fails on any other failure,
# and on a listed test that passes.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SOURCE=${PROTOBUF_SOURCE:?set PROTOBUF_SOURCE to a protobuf checkout with conformance_test_runner built in build/}
RUNNER="$SOURCE/build/conformance_test_runner"
[ -x "$RUNNER" ] || { echo "no $RUNNER; build it first (see the comment at the top)" >&2; exit 2; }
cd "$ROOT"
swift build --product protoc-gen-aemi >/dev/null
PLUGIN="$(swift build --show-bin-path)/protoc-gen-aemi"
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
PROTOC=${PROTOC:-protoc}
(cd "$SOURCE" && "$PROTOC" -Isrc -I. --plugin=protoc-gen-aemi="$PLUGIN" --aemi_out="$OUT" \
    conformance/conformance.proto google/protobuf/test_messages_proto3.proto google/protobuf/test_messages_proto2.proto \
    editions/golden/test_messages_proto2_editions.proto editions/golden/test_messages_proto3_editions.proto \
    conformance/test_protos/test_messages_edition2023.proto google/protobuf/any.proto google/protobuf/duration.proto \
    google/protobuf/field_mask.proto google/protobuf/struct.proto google/protobuf/timestamp.proto \
    google/protobuf/wrappers.proto google/protobuf/empty.proto)
TESTEE_SOURCES="$ROOT/Conformance/Sources/AemiConformanceTestee"
find "$OUT" -name '*.aemi.swift' | while read -r file; do
    base=$(basename "$file" .aemi.swift)
    name=$(printf '%s' "$base" | awk -F_ '{ for (i = 1; i <= NF; i++) printf "%s", toupper(substr($i, 1, 1)) substr($i, 2) }')
    cp "$file" "$TESTEE_SOURCES/Generated$name.swift"
done
(cd Conformance && swift build -c release --product AemiConformanceTestee)
TESTEE="$ROOT/Conformance/$(cd Conformance && swift build -c release --show-bin-path | sed "s|^$ROOT/Conformance/||")/AemiConformanceTestee"
"$RUNNER" --enforce_recommended --failure_list Conformance/failure_list.txt --maximum_edition 2023 "$TESTEE"
