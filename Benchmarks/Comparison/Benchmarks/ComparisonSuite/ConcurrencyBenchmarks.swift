import AemiJSON
import AemiProtobuf
import Benchmark
import ComparisonShared
import Foundation
import SwiftProtobuf

/// Eight independent payloads decoded one after another and across a task group: how each format scales over cores.
func registerConcurrencyBenchmarks() {
    let c = corpusCodecs(2_000)
    let copies = 8
    let aemiDecoder = AemiJSON.JSONDecoder()
    let pbDecoder = ProtobufDecoder()
    let json = c.jsonAemi
    let pb = c.protoFast

    Benchmark("concurrent/serial8/json.AemiJSON.codable") { bm in
        for _ in bm.scaledIterations {
            for _ in 0 ..< copies { blackHole(try aemiDecoder.decode([JSONUser].self, from: json)) }
        }
    }
    Benchmark("concurrent/parallel8/json.AemiJSON.codable") { bm in
        for _ in bm.scaledIterations {
            try await withThrowingTaskGroup(of: Int.self) { group in
                for _ in 0 ..< copies {
                    group.addTask { try AemiJSON.JSONDecoder().decode([JSONUser].self, from: json).count }
                }
                for try await count in group { blackHole(count) }
            }
        }
    }
    Benchmark("concurrent/serial8/pb.AemiProtobuf.fast") { bm in
        for _ in bm.scaledIterations {
            for _ in 0 ..< copies { blackHole(try pbDecoder.decode(ProtoUsers.self, fromBytes: pb)) }
        }
    }
    Benchmark("concurrent/parallel8/pb.AemiProtobuf.fast") { bm in
        for _ in bm.scaledIterations {
            try await withThrowingTaskGroup(of: Int.self) { group in
                for _ in 0 ..< copies {
                    group.addTask { try pbDecoder.decode(ProtoUsers.self, fromBytes: pb).users.count }
                }
                for try await count in group { blackHole(count) }
            }
        }
    }
    Benchmark("concurrent/serial8/pb.SwiftProtobuf") { bm in
        for _ in bm.scaledIterations {
            for _ in 0 ..< copies { blackHole(try Users(serializedBytes: pb)) }
        }
    }
    Benchmark("concurrent/parallel8/pb.SwiftProtobuf") { bm in
        for _ in bm.scaledIterations {
            try await withThrowingTaskGroup(of: Int.self) { group in
                for _ in 0 ..< copies { group.addTask { try Users(serializedBytes: pb).users.count } }
                for try await count in group { blackHole(count) }
            }
        }
    }

    // An allocation-free workload: if this scales better than the decodes, the decodes are limited by the allocator.
    Benchmark("concurrent/serial8/pb.AemiProtobuf.read2") { bm in
        for _ in bm.scaledIterations {
            for _ in 0 ..< copies { blackHole(try protobufReadTwoFields(pb)) }
        }
    }
    Benchmark("concurrent/parallel8/pb.AemiProtobuf.read2") { bm in
        for _ in bm.scaledIterations {
            try await withThrowingTaskGroup(of: Int.self) { group in
                for _ in 0 ..< copies { group.addTask { try protobufReadTwoFields(pb) } }
                for try await count in group { blackHole(count) }
            }
        }
    }
}
