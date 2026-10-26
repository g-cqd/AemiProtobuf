---
status: not-started
blocked-by: []
date: 2026-10-25
---

# 0015 — Release archives for fcheck and modeler

Scope: `fcheck` and `modeler` publish no release archive, so `Scripts/tools.sh` builds them from a pinned commit (about eight
minutes cold). Ask the owner to publish `macos-arm64` and `linux-x86_64` archives as arcleak, dolly and deadwood do, then pin them by
version and SHA-256 in `Scripts/tools.lock`. Not this repository's code; a follow-up for `g-cqd/fcheck` and `g-cqd/modeler`.
