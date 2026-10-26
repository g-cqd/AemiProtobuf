import AemiProtobuf
import AemiProtobufCore
import Benchmark
import ComparisonShared
import Foundation

/// Messages with 10 and 100 declared fields, every field set: does cost per field grow with the field count?
func registerWideBenchmarks() {
    registerWide("fields10", Wide10.filled)
    registerWide("fields100", Wide100.filled)
}

private func registerWide<M: Codable & AemiProtoFastEncodable & AemiProtoFastDecodable & Equatable>(
    _ name: String, _ value: M
) {
    let encoder = ProtobufEncoder()
    let decoder = ProtobufDecoder()
    guard let bytes = try? encoder.encodeToBytes(value), (try? decoder.decode(M.self, fromBytes: bytes)) == value else {
        FileHandle.standardError.write(Data("wide/\(name): the message does not round-trip\n".utf8))
        exit(1)
    }
    Benchmark("wide/\(name)/encode") { bm in
        for _ in bm.scaledIterations { blackHole(try encoder.encodeToBytes(value)) }
    }
    Benchmark("wide/\(name)/decode") { bm in
        for _ in bm.scaledIterations { blackHole(try decoder.decode(M.self, fromBytes: bytes)) }
    }
    Benchmark("wide/\(name)/decodeFromData") { bm in
        let data = Data(bytes)
        for _ in bm.scaledIterations { blackHole(try decoder.decode(M.self, from: data)) }
    }
}
