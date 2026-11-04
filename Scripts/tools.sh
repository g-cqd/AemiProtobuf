#!/bin/sh
# Installs the pinned quality tools (Scripts/tools.lock) into a cache outside the repository, and prints where each one is.
#
#   Scripts/tools.sh install [tool...]   install the named tools, or all that this platform can run
#   Scripts/tools.sh path <tool>         print the executable (or jar) of an installed tool; exit 2 if it is not installed
#
# Tools: mutation (the analyzers, modeler included, and TLC are swift-ci's, from its tool lock)
# Exit: 0 ok, 2 a tool could not be installed or is not available on this platform.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=Scripts/tools.lock
. "$ROOT/Scripts/tools.lock"

case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) PLATFORM=macos_arm64 CACHE_ROOT="$HOME/Library/Caches" ;;
    Linux-x86_64) PLATFORM=linux_x86_64 CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}" ;;
    *) PLATFORM=unsupported CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}" ;;
esac
CACHE="${AEMIPROTOBUF_TOOLS_DIR:-$CACHE_ROOT/aemiprotobuf/tools}"

fail() { printf '[FAIL] %s\n' "$1" >&2; exit "${2:-2}"; }

sha256() {
    if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi
}

# value of a pinned variable such as DEADWOOD_SHA_macos_arm64
pinned() { eval "printf '%s' \"\${$1:-}\""; }

download() { # url destination expected-sha
    curl -fsSL --retry 3 -o "$2" "$1" || fail "download failed: $1"
    actual=$(sha256 "$2")
    [ "$actual" = "$3" ] || fail "$1: hash $actual is not the pinned $3"
}

scratch=""
cleanup() { [ -n "$scratch" ] && rm -rf "$scratch"; return 0; }
trap cleanup EXIT

install_mutation() {
    sha=$(pinned "MUTATION_SHA_$PLATFORM")
    [ -n "$sha" ] || fail "swift-mutation-testing is pinned for macOS arm64 only"
    dir="$CACHE/swift-mutation-testing-$MUTATION_VERSION"
    [ -x "$dir/swift-mutation-testing" ] && return 0
    scratch=$(mktemp -d)
    name="swift-mutation-testing-v$MUTATION_VERSION-macos"
    printf '==> installing swift-mutation-testing %s\n' "$MUTATION_VERSION"
    download "https://github.com/ericodx/swift-mutation-testing/releases/download/v$MUTATION_VERSION/$name.tar.gz" \
        "$scratch/$name.tar.gz" "$sha"
    mkdir -p "$dir"
    tar -xzf "$scratch/$name.tar.gz" -C "$dir"
    # The archive holds the binary at its top level or in one directory; find it either way.
    found=$(find "$dir" -name swift-mutation-testing -type f | head -n 1)
    [ -n "$found" ] || fail "swift-mutation-testing: no binary in the archive"
    [ "$found" = "$dir/swift-mutation-testing" ] || mv "$found" "$dir/swift-mutation-testing"
    chmod +x "$dir/swift-mutation-testing"
}

install_one() {
    case "$1" in
        mutation) install_mutation ;;
        *) fail "unknown tool: $1" ;;
    esac
}

tool_path() {
    case "$1" in
        mutation) echo "$CACHE/swift-mutation-testing-$MUTATION_VERSION/swift-mutation-testing" ;;
        *) fail "unknown tool: $1" ;;
    esac
}

case "${1:-}" in
    install)
        shift
        if [ "$#" -eq 0 ]; then
            [ "$PLATFORM" = macos_arm64 ] || fail "swift-mutation-testing is pinned for macOS arm64 only"
            set -- mutation
        fi
        for tool in "$@"; do install_one "$tool"; done
        ;;
    path)
        [ -n "${2:-}" ] || fail "usage: tools.sh path <tool>"
        p=$(tool_path "$2")
        [ -e "$p" ] || { printf '[FAIL] %s is not installed; run Scripts/tools.sh install %s\n' "$2" "$2" >&2; exit 2; }
        echo "$p"
        ;;
    *) fail "usage: tools.sh install [tool...] | path <tool>" ;;
esac
