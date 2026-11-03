# CI

`action.json` configures the pinned swift-ci graph and local `swift-ci run`
commands. Quality retains all four static analyzers and the prior formatting
scope, including Benchmarks and Conformance. Modeler still runs with Lean/TLC
in the model job. The existing root dolly baseline is retained.

Per change: Linux debug/release/ASan and macOS debug, coverage floors, then the
opt-in NIO tests on the warm macOS tree. The coverage script reuses the existing
coverage run in CI; its standalone default still runs tests. Release tests are
built once with testing enabled and then run with --skip-build.

Nightly/manual: macOS release/sanitizers, Linux TSan, DocC, protobuf conformance,
Lean/TLC/modeler, allocation thresholds and mutation testing. The conformance
version remains configurable via PROTOBUF_VERSION. Integration jobs retain
their setup and cache their SwiftPM trees separately.

Only ASan skips the existing deeply-nested-input test: instrumentation makes
its Codable recursion exceed the test thread's stack. Debug, release and TSan
still run it. Fixture lookup uses Bundle's resource API rather than appending
Resources to resourceURL, which duplicated that component on Linux.
