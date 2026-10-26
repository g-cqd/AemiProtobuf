import AemiJSON
import AemiProtobuf
import AemiProtobufCore
import Benchmark
import ComparisonShared
import Foundation
import SwiftProtobuf

/// Number-heavy arrays: JSON text against packed protobuf, four value distributions, 100,000 elements.
func registerNumberBenchmarks() {
    let count = 100_000
    func doubles(_ v: [Double]) -> Doubles {
        var m = Doubles()
        m.values = v
        return m
    }
    func ints(_ v: [Int64]) -> Int64s {
        var m = Int64s()
        m.values = v
        return m
    }
    registerNumbers(
        "doublesFull", values: Corpus.fullPrecisionDoubles(count), fast: PackedDoubles.init, spMake: doubles)
    registerNumbers("doublesShort", values: Corpus.shortDoubles(count), fast: PackedDoubles.init, spMake: doubles)
    registerNumbers("intsWide", values: Corpus.wideIntegers(count), fast: PackedInt64s.init, spMake: ints)
    registerNumbers("intsSmall", values: Corpus.smallIntegers(count), fast: PackedInt64s.init, spMake: ints)
}

private func registerNumbers<
    E: Codable & Equatable, F: Codable & AemiProtoFastEncodable & AemiProtoFastDecodable & Equatable,
    M: SwiftProtobuf.Message & Equatable
>(_ name: String, values: [E], fast make: @escaping ([E]) -> F, spMake: ([E]) -> M) {
    let spValue = spMake(values)
    let aemiEncoder = AemiJSON.JSONEncoder()
    let aemiDecoder = AemiJSON.JSONDecoder()
    let pbEncoder = ProtobufEncoder()
    let pbDecoder = ProtobufDecoder()
    let fastValue = make(values)
    let codableValue = RepeatedMessage(values)
    guard let json = try? aemiEncoder.encode(values), let pbFast = try? pbEncoder.encodeToBytes(fastValue),
        let pbCodable = try? pbEncoder.encodeToBytes(codableValue), pbFast == pbCodable,
        (try? aemiDecoder.decode([E].self, from: json)) == values,
        (try? Foundation.JSONDecoder().decode([E].self, from: json)) == values,
        (try? pbDecoder.decode(RepeatedMessage<E>.self, fromBytes: pbFast))?.values == values,
        (try? spValue.serializedBytes() as [UInt8]) == pbFast,
        (try? M(serializedBytes: pbFast)) == spValue
    else {
        FileHandle.standardError.write(Data("numbers/\(name): a codec failed its round trip\n".utf8))
        exit(1)
    }

    Benchmark("numbers/\(name)/encode/json.AemiJSON") { bm in
        for _ in bm.scaledIterations { blackHole(try aemiEncoder.encode(values)) }
    }
    Benchmark("numbers/\(name)/encode/json.Foundation") { bm in
        for _ in bm.scaledIterations { blackHole(try foundationEncoder.encode(values)) }
    }
    Benchmark("numbers/\(name)/encode/pb.AemiProtobuf.fast") { bm in
        for _ in bm.scaledIterations { blackHole(try pbEncoder.encodeToBytes(fastValue)) }
    }
    Benchmark("numbers/\(name)/encode/pb.AemiProtobuf.codable") { bm in
        for _ in bm.scaledIterations { blackHole(try pbEncoder.encodeToBytes(codableValue)) }
    }
    Benchmark("numbers/\(name)/encode/pb.SwiftProtobuf") { bm in
        for _ in bm.scaledIterations { blackHole(try spValue.serializedBytes() as [UInt8]) }
    }
    Benchmark("numbers/\(name)/decode/pb.SwiftProtobuf") { bm in
        for _ in bm.scaledIterations { blackHole(try M(serializedBytes: pbFast)) }
    }
    Benchmark("numbers/\(name)/decode/json.AemiJSON") { bm in
        for _ in bm.scaledIterations { blackHole(try aemiDecoder.decode([E].self, from: json)) }
    }
    Benchmark("numbers/\(name)/decode/json.Foundation") { bm in
        for _ in bm.scaledIterations { blackHole(try foundationDecoder.decode([E].self, from: json)) }
    }
    Benchmark("numbers/\(name)/decode/pb.AemiProtobuf.fast") { bm in
        for _ in bm.scaledIterations { blackHole(try pbDecoder.decode(F.self, fromBytes: pbFast)) }
    }
    Benchmark("numbers/\(name)/decode/pb.AemiProtobuf.codable") { bm in
        for _ in bm.scaledIterations { blackHole(try pbDecoder.decode(RepeatedMessage<E>.self, fromBytes: pbFast)) }
    }
}
