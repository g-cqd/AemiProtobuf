---
status: done
blocked-by: []
date: 2026-10-25
---

# 0015 — Release archives for fcheck and modeler

Scope: `fcheck` and `modeler` publish no release archive, so `Scripts/tools.sh` builds them from a pinned commit (about eight
minutes cold). Ask the owner to publish `macos-arm64` and `linux-x86_64` archives as arcleak, dolly and deadwood do, then pin them by
version and SHA-256 in `Scripts/tools.lock`. Not this repository's code; a follow-up for `g-cqd/fcheck` and `g-cqd/modeler`.

## Done (2026-10-31)

fcheck 0.2.0 and modeler 0.2.0 publish both archives (github.com/g-cqd/fcheck/releases/tag/v0.2.0,
github.com/g-cqd/modeler/releases/tag/v0.2.0). `Scripts/tools.lock` pins them by version and SHA-256 like the other three,
and `Scripts/tools.sh` installs them with `install_release`; `install_source` is gone (`8f25cf5`). The bump surfaced three
`cut-then-decode` warnings in `ProtoJSONNumber.split`, there since fcheck learned `dropFirst` before 0.1.0; its slices are
ASCII digits, so they are accepted in place with the reason.
