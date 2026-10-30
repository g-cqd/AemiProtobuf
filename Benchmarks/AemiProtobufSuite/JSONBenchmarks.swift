import AemiProtobuf
import AemiProtobufJSON
import AemiProtobufSchema
import Benchmark
import Foundation

/// Roadmap 0010: the 1,000-user corpus through the JSON mapping, both ways.
enum JSONBenchmarks {
    static func register() {
        let schema = DynamicSchema(ViewBenchmarks.users)
        let coder = ProtoJSONCoder(schema: schema)
        let json: [UInt8]
        let message: DynamicMessage
        do {
            let bytes = try ProtobufEncoder().encodeToBytes(MacroUsers(UserRecord.corpus(count: 1_000)))
            message = try schema.decode(bytes, as: "bench.Users")
            json = try coder.encode(message)
            guard try schema.encode(try coder.decode(json: json, as: "bench.Users")) == bytes else {
                throw CheckFailure("JSON does not round-trip the corpus")
            }
        } catch {
            FileHandle.standardError.write(Data("JSON benchmarks: \(error)\n".utf8))
            exit(1)
        }
        Benchmark("JSON.encode") { bm in
            for _ in bm.scaledIterations { blackHole(try coder.encode(message)) }
        }
        Benchmark("JSON.decode") { bm in
            for _ in bm.scaledIterations { blackHole(try coder.decode(json: json, as: "bench.Users")) }
        }
    }
}
