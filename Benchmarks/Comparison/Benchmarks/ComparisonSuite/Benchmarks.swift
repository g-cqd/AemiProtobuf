import Benchmark

// AemiJSON and AemiProtobuf on the same logical data. Run from this directory:
//   swift package benchmark                      everything
//   swift package benchmark --filter 'encode/.*' one group
// Every codec is round-trip checked at setup; a failure exits with the reason instead of timing broken work.
nonisolated(unsafe) let benchmarks: () -> Void = {
    Benchmark.defaultConfiguration = .init(
        metrics: [.wallClock, .throughput, .cpuTotal, .mallocCountTotal], maxDuration: .seconds(2),
        maxIterations: 50_000)
    registerRecordBenchmarks()
    registerNavigationBenchmarks()
    registerNumberBenchmarks()
    registerStringBenchmarks()
    registerNestingBenchmarks()
    registerConcurrencyBenchmarks()
    registerWideBenchmarks()
    registerFramingBenchmarks()
}
