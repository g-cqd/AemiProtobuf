import AemiJSON
import AemiProtobuf
import AemiProtobufCore
import Benchmark
import ComparisonShared
import Foundation
import SwiftProtobuf

/// String arrays in four classes: ASCII, multi-byte UTF-8, strings JSON must escape, and long strings. 20,000 strings each.
func registerStringBenchmarks() {
    let aemiEncoder = AemiJSON.JSONEncoder()
    let aemiDecoder = AemiJSON.JSONDecoder()
    let pbEncoder = ProtobufEncoder()
    let pbDecoder = ProtobufDecoder()
    for kind in Corpus.StringKind.allCases {
        let values = Corpus.strings(20_000, kind: kind)
        let fastValue = RepeatedStrings(values)
        let codableValue = RepeatedMessage(values)
        var spValue = Strings()
        spValue.values = values
        guard let json = try? aemiEncoder.encode(values), let pbFast = try? pbEncoder.encodeToBytes(fastValue),
            (try? pbEncoder.encodeToBytes(codableValue)) == pbFast,
            (try? aemiDecoder.decode([String].self, from: json)) == values,
            (try? Foundation.JSONDecoder().decode([String].self, from: json)) == values,
            (try? pbDecoder.decode(RepeatedMessage<String>.self, fromBytes: pbFast))?.values == values,
            (try? spValue.serializedBytes() as [UInt8]) == pbFast, (try? Strings(serializedBytes: pbFast)) == spValue
        else {
            FileHandle.standardError.write(Data("strings/\(kind): a codec failed its round trip\n".utf8))
            exit(1)
        }
        let name = "strings/\(kind.rawValue)"
        Benchmark("\(name)/encode/json.AemiJSON") { bm in
            for _ in bm.scaledIterations { blackHole(try aemiEncoder.encode(values)) }
        }
        Benchmark("\(name)/encode/json.Foundation") { bm in
            for _ in bm.scaledIterations { blackHole(try foundationEncoder.encode(values)) }
        }
        Benchmark("\(name)/encode/pb.AemiProtobuf.fast") { bm in
            for _ in bm.scaledIterations { blackHole(try pbEncoder.encodeToBytes(fastValue)) }
        }
        Benchmark("\(name)/encode/pb.AemiProtobuf.codable") { bm in
            for _ in bm.scaledIterations { blackHole(try pbEncoder.encodeToBytes(codableValue)) }
        }
        Benchmark("\(name)/encode/pb.SwiftProtobuf") { bm in
            for _ in bm.scaledIterations { blackHole(try spValue.serializedBytes() as [UInt8]) }
        }
        Benchmark("\(name)/decode/pb.SwiftProtobuf") { bm in
            for _ in bm.scaledIterations { blackHole(try Strings(serializedBytes: pbFast)) }
        }
        Benchmark("\(name)/decode/json.AemiJSON") { bm in
            for _ in bm.scaledIterations { blackHole(try aemiDecoder.decode([String].self, from: json)) }
        }
        Benchmark("\(name)/decode/json.Foundation") { bm in
            for _ in bm.scaledIterations { blackHole(try foundationDecoder.decode([String].self, from: json)) }
        }
        Benchmark("\(name)/decode/pb.AemiProtobuf.fast") { bm in
            for _ in bm.scaledIterations { blackHole(try pbDecoder.decode(RepeatedStrings.self, fromBytes: pbFast)) }
        }
        Benchmark("\(name)/decode/pb.AemiProtobuf.codable") { bm in
            for _ in bm.scaledIterations {
                blackHole(try pbDecoder.decode(RepeatedMessage<String>.self, fromBytes: pbFast))
            }
        }
    }
}
