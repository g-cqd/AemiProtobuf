---
status: done
blocked-by: []
date: 2026-10-29
---

# 0029 — Linux in CI

From roadmap 0013. No job runs on Linux. Scope: a Linux job for the tests (debug and release) with the toolchain `.swift-version`
names; swift-format there; the gates that need macOS (`model`, allocation thresholds) stay on macOS and say so.

## Done (2026-10-30)

Verified locally first, in Apple's `container` with the `swift:6.4` image (aarch64 Linux; the dependencies copied from the host's
checkouts, as the container has no network, and SwiftPM's macOS swift-syntax prebuilts turned off): the package builds and the
whole suite passes in debug and in release. CI job `linux` (ubuntu-24.04, x86_64) runs `Scripts/quality.sh test` with the
`.swift-version` toolchain. Format, lint and the analyzers stay on macOS, where the pinned tool archives are; the models and the
allocation thresholds stay on macOS too (Lean, TLC and the malloc interposer are installed there).
