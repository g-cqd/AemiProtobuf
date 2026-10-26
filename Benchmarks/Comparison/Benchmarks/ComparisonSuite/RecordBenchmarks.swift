import AemiJSON
import AemiProtobuf
import AemiProtobufCore
import Benchmark
import ComparisonShared
import Foundation
import SwiftProtobuf

/// Encode, decode and round trip of the typed record list, every codec, four sizes.
func registerRecordBenchmarks() {
    for n in [1, 100, 2_000, 20_000] {
        let c = corpusCodecs(n)
        let tag = "n\(n)"
        let aemiEncoder = AemiJSON.JSONEncoder()
        let aemiDecoder = AemiJSON.JSONDecoder()
        let pbEncoder = ProtobufEncoder()
        let pbDecoder = ProtobufDecoder()

        // MARK: encode
        Benchmark("encode/\(tag)/json.AemiJSON.codable") { bm in
            for _ in bm.scaledIterations { blackHole(try aemiEncoder.encode(c.jsonUsers)) }
        }
        Benchmark("encode/\(tag)/json.AemiJSON.macro") { bm in
            for _ in bm.scaledIterations { blackHole(try aemiEncoder.encode(c.macroUsers)) }
        }
        Benchmark("encode/\(tag)/json.Foundation") { bm in
            for _ in bm.scaledIterations { blackHole(try foundationEncoder.encode(c.jsonUsers)) }
        }
        Benchmark("encode/\(tag)/pb.AemiProtobuf.fast") { bm in
            for _ in bm.scaledIterations { blackHole(try pbEncoder.encodeToBytes(c.protoUsers)) }
        }
        Benchmark("encode/\(tag)/pb.AemiProtobuf.fastDirect") { bm in
            for _ in bm.scaledIterations {
                var w = WireWriter(reservingCapacity: 128)
                try c.protoUsers.__aepbEncode(into: &w)
                blackHole(w.bytes)
            }
        }
        Benchmark("encode/\(tag)/pb.AemiProtobuf.codable") { bm in
            for _ in bm.scaledIterations { blackHole(try pbEncoder.encodeToBytes(c.codableProtoUsers)) }
        }

        Benchmark("encode/\(tag)/pb.SwiftProtobuf") { bm in
            for _ in bm.scaledIterations { blackHole(try c.swiftProtobufUsers.serializedBytes() as [UInt8]) }
        }

        // MARK: decode
        Benchmark("decode/\(tag)/json.AemiJSON.codable") { bm in
            for _ in bm.scaledIterations { blackHole(try aemiDecoder.decode([JSONUser].self, from: c.jsonAemi)) }
        }
        Benchmark("decode/\(tag)/json.AemiJSON.macro") { bm in
            for _ in bm.scaledIterations { blackHole(try aemiDecoder.decode([MacroJSONUser].self, from: c.jsonAemi)) }
        }
        Benchmark("decode/\(tag)/json.Foundation") { bm in
            for _ in bm.scaledIterations { blackHole(try foundationDecoder.decode([JSONUser].self, from: c.jsonAemi)) }
        }
        Benchmark("decode/\(tag)/pb.AemiProtobuf.fast") { bm in
            for _ in bm.scaledIterations { blackHole(try pbDecoder.decode(ProtoUsers.self, fromBytes: c.protoFast)) }
        }
        Benchmark("decode/\(tag)/pb.AemiProtobuf.fastDirect") { bm in
            for _ in bm.scaledIterations {
                blackHole(
                    try WireReader.withReader(over: c.protoFast) { r throws(WireError) in
                        try ProtoUsers.__aepbDecode(from: &r)
                    })
            }
        }
        Benchmark("decode/\(tag)/pb.AemiProtobuf.codable") { bm in
            for _ in bm.scaledIterations {
                blackHole(try pbDecoder.decode(CodableProtoUsers.self, fromBytes: c.protoFast))
            }
        }

        Benchmark("decode/\(tag)/pb.SwiftProtobuf") { bm in
            for _ in bm.scaledIterations { blackHole(try Users(serializedBytes: c.protoFast)) }
        }

        // MARK: round trip (encode then decode, as a service does for each message it relays)
        guard n == 2_000 else { continue }
        Benchmark("roundtrip/\(tag)/json.AemiJSON.codable") { bm in
            for _ in bm.scaledIterations {
                blackHole(try aemiDecoder.decode([JSONUser].self, from: try aemiEncoder.encode(c.jsonUsers)))
            }
        }
        Benchmark("roundtrip/\(tag)/json.AemiJSON.macro") { bm in
            for _ in bm.scaledIterations {
                blackHole(try aemiDecoder.decode([MacroJSONUser].self, from: try aemiEncoder.encode(c.macroUsers)))
            }
        }
        Benchmark("roundtrip/\(tag)/json.Foundation") { bm in
            for _ in bm.scaledIterations {
                blackHole(
                    try foundationDecoder.decode([JSONUser].self, from: try foundationEncoder.encode(c.jsonUsers)))
            }
        }
        Benchmark("roundtrip/\(tag)/pb.AemiProtobuf.fast") { bm in
            for _ in bm.scaledIterations {
                blackHole(try pbDecoder.decode(ProtoUsers.self, fromBytes: try pbEncoder.encodeToBytes(c.protoUsers)))
            }
        }
        Benchmark("roundtrip/\(tag)/pb.SwiftProtobuf") { bm in
            for _ in bm.scaledIterations {
                let bytes: [UInt8] = try c.swiftProtobufUsers.serializedBytes()
                blackHole(try Users(serializedBytes: bytes))
            }
        }
        Benchmark("roundtrip/\(tag)/pb.AemiProtobuf.codable") { bm in
            for _ in bm.scaledIterations {
                blackHole(
                    try pbDecoder.decode(
                        CodableProtoUsers.self, fromBytes: try pbEncoder.encodeToBytes(c.codableProtoUsers)))
            }
        }
    }
}
