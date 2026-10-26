import AemiJSON
import Benchmark
import ComparisonShared
import Foundation

/// A chain of nested objects, depth 10, 50 and 90: JSON navigation against protobuf descent, the cost of depth.
func registerNestingBenchmarks() {
    for depth in [10, 50, 90] {
        let json = Data(Nesting.json(depth: depth))
        let pb = Nesting.protobuf(depth: depth)
        guard (try? protobufDescend(pb)) == depth, (try? AemiJSON.parse(json)) != nil else {
            FileHandle.standardError.write(Data("nesting/\(depth): a fixture does not parse\n".utf8))
            exit(1)
        }
        Benchmark("nesting/depth\(depth)/json.AemiJSON.tape") { bm in
            for _ in bm.scaledIterations { blackHole(jsonWalk(try AemiJSON.parse(json).root)) }
        }
        Benchmark("nesting/depth\(depth)/json.Foundation.JSONSerialization") { bm in
            for _ in bm.scaledIterations { blackHole(try JSONSerialization.jsonObject(with: json)) }
        }
        Benchmark("nesting/depth\(depth)/pb.AemiProtobuf.descend") { bm in
            for _ in bm.scaledIterations { blackHole(try protobufDescend(pb)) }
        }
    }
}
