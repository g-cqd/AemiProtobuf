#!/bin/sh
# Installs the pinned quality tools (Scripts/tools.lock) into a cache outside the repository, and prints where each one is.
#
#   Scripts/tools.sh install [tool...]   install the named tools, or all that this platform can run
#   Scripts/tools.sh path <tool>         print the executable (or jar) of an installed tool; exit 2 if it is not installed
#
# Tools: deadwood dolly arcleak fcheck modeler tla2tools mutation
# Exit: 0 ok, 2 a tool could not be installed or is not available on this platform.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=Scripts/tools.lock
. "$ROOT/Scripts/tools.lock"

case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) PLATFORM=macos_arm64 ARCHIVE=macos-arm64 CACHE_ROOT="$HOME/Library/Caches" ;;
    Linux-x86_64) PLATFORM=linux_x86_64 ARCHIVE=linux-x86_64 CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}" ;;
    *) PLATFORM=unsupported ARCHIVE=unsupported CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}" ;;
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

install_release() { # tool VERSION-variable-prefix
    tool=$1 upper=$2
    version=$(pinned "${upper}_VERSION")
    sha=$(pinned "${upper}_SHA_$PLATFORM")
    [ -n "$sha" ] || fail "$tool: no archive is pinned for $(uname -s)-$(uname -m)"
    dir="$CACHE/$tool-$version"
    [ -x "$dir/$tool" ] && return 0
    scratch=$(mktemp -d)
    name="$tool-$version-$ARCHIVE"
    printf '==> installing %s %s\n' "$tool" "$version"
    download "https://github.com/g-cqd/$tool/releases/download/v$version/$name.tar.gz" "$scratch/$name.tar.gz" "$sha"
    tar -xzf "$scratch/$name.tar.gz" -C "$scratch"
    mkdir -p "$dir"
    cp -R "$scratch/$name/." "$dir/"   # the whole directory: the Linux archive carries Swift runtime libraries beside the binary
    reported=$("$dir/$tool" --version 2>/dev/null || true)
    [ "$reported" = "$version" ] || { rm -rf "$dir"; fail "$tool reports '$reported', not $version"; }
}

install_source() { # tool COMMIT-variable-prefix
    tool=$1 upper=$2
    commit=$(pinned "${upper}_COMMIT")
    short=$(printf '%s' "$commit" | cut -c1-12)
    dir="$CACHE/$tool-$short"
    [ -x "$dir/$tool" ] && return 0
    scratch=$(mktemp -d)
    printf '==> building %s at %s (several minutes)\n' "$tool" "$short"
    git clone --quiet "https://github.com/g-cqd/$tool.git" "$scratch/$tool" || fail "$tool: clone failed"
    git -C "$scratch/$tool" checkout --quiet "$commit" || fail "$tool: commit $commit not found"
    [ "$(git -C "$scratch/$tool" rev-parse HEAD)" = "$commit" ] || fail "$tool: checked out the wrong commit"
    (cd "$scratch/$tool" && swift build -c release --product "$tool") >&2 || fail "$tool: build failed"
    mkdir -p "$dir"
    cp "$scratch/$tool/.build/release/$tool" "$dir/$tool"
}

install_tla() {
    jar="$CACHE/tla2tools-$TLA2TOOLS_VERSION.jar"
    [ -f "$jar" ] && return 0
    scratch=$(mktemp -d)
    printf '==> installing tla2tools %s\n' "$TLA2TOOLS_VERSION"
    download "https://github.com/tlaplus/tlaplus/releases/download/v$TLA2TOOLS_VERSION/tla2tools.jar" \
        "$scratch/tla2tools.jar" "$TLA2TOOLS_SHA"
    mkdir -p "$CACHE"
    mv "$scratch/tla2tools.jar" "$jar"
}

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
        deadwood) install_release deadwood DEADWOOD ;;
        dolly) install_release dolly DOLLY ;;
        arcleak) install_release arcleak ARCLEAK ;;
        fcheck) install_source fcheck FCHECK ;;
        modeler) install_source modeler MODELER ;;
        tla2tools) install_tla ;;
        mutation) install_mutation ;;
        *) fail "unknown tool: $1" ;;
    esac
}

tool_path() {
    case "$1" in
        deadwood) echo "$CACHE/deadwood-$DEADWOOD_VERSION/deadwood" ;;
        dolly) echo "$CACHE/dolly-$DOLLY_VERSION/dolly" ;;
        arcleak) echo "$CACHE/arcleak-$ARCLEAK_VERSION/arcleak" ;;
        fcheck) echo "$CACHE/fcheck-$(printf '%s' "$FCHECK_COMMIT" | cut -c1-12)/fcheck" ;;
        modeler) echo "$CACHE/modeler-$(printf '%s' "$MODELER_COMMIT" | cut -c1-12)/modeler" ;;
        tla2tools) echo "$CACHE/tla2tools-$TLA2TOOLS_VERSION.jar" ;;
        mutation) echo "$CACHE/swift-mutation-testing-$MUTATION_VERSION/swift-mutation-testing" ;;
        *) fail "unknown tool: $1" ;;
    esac
}

case "${1:-}" in
    install)
        shift
        if [ "$#" -eq 0 ]; then
            set -- deadwood dolly arcleak fcheck modeler tla2tools
            [ "$PLATFORM" = macos_arm64 ] && set -- "$@" mutation
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
