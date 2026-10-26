import AemiProtobufCore
import Benchmark
import Foundation

/// Release only (`Scripts/quality.sh bench`). The corpus is the 1,000-user message of the throughput probe, so a number here can be
/// set beside the probe's hand-written path (ADR-0005). Run to run on a busy machine the wall clock moves; the allocation counts do not.
let benchmarks: @Sendable () -> Void = {
    // `AEMIPROTOBUF_BENCH_GATE=1` measures allocations only: they are exact, so a threshold on them cannot flake. The wall clock
    // moves with the machine (a median held 220 to 297 µs across two runs here), so it is reported and never gated.
    let gate = ProcessInfo.processInfo.environment["AEMIPROTOBUF_BENCH_GATE"] != nil
    Benchmark.defaultConfiguration = .init(
        metrics: gate ? [.mallocCountTotal] : [.wallClock, .mallocCountTotal, .throughput], scalingFactor: .one,
        maxDuration: .seconds(3),
        maxIterations: 10_000,
        thresholds: [.mallocCountTotal: .strict])

    SchemaBenchmarks.register()
    registerCoderBenchmarks()

    let records = UserRecord.corpus(count: 1_000)
    // An empty buffer on failure makes the read benchmark visibly trivial instead of crashing the harness.
    let encoded = (try? UserRecord.encode(records)) ?? []

    Benchmark("Users1000.write") { benchmark in
        for _ in benchmark.scaledIterations { blackHole((try? UserRecord.encode(records))?.count) }
    }

    Benchmark("Users1000.read") { benchmark in
        for _ in benchmark.scaledIterations { blackHole(try? UserRecord.checksum(of: encoded)) }
    }

    let varints: [UInt64] = (0 ..< 4_096).map { UInt64(1) << UInt64($0 % 64) &- UInt64($0 & 1) }
    Benchmark("Varint4096.write") { benchmark in
        for _ in benchmark.scaledIterations {
            var writer = WireWriter(reservingCapacity: 4_096 * 6)
            for value in varints { writer.appendVarint(value) }
            blackHole(writer.bytes.count)
        }
    }

    var varintBytes = WireWriter()
    for value in varints { varintBytes.appendVarint(value) }
    let varintBuffer = varintBytes.bytes
    Benchmark("Varint4096.read") { benchmark in
        for _ in benchmark.scaledIterations {
            let sum = try? WireReader.withReader(over: varintBuffer) { r throws(WireError) in
                var sum: UInt64 = 0
                while !r.isAtEnd { sum &+= try r.readVarint() }
                return sum
            }
            blackHole(sum)
        }
    }

    Benchmark("Group3Deep1000.skip") { benchmark in
        var w = WireWriter()
        for _ in 0 ..< 1_000 {
            for number: FieldNumber in [1, 2, 3] { w.appendTag(number, .startGroup) }
            w.appendTag(9, .varint)
            w.appendVarint(1)
            for number: FieldNumber in [3, 2, 1] { w.appendTag(number, .endGroup) }
        }
        let bytes = w.bytes
        for _ in benchmark.scaledIterations {
            let count = try? WireReader.withReader(over: bytes) { r throws(WireError) in
                var count = 0
                while let tag = try r.nextTag() {
                    try r.skipField(tag)
                    count += 1
                }
                return count
            }
            blackHole(count)
        }
    }
}
