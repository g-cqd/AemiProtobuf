import AemiProtobuf
import AemiProtobufCore
import Benchmark
import ComparisonShared
import Foundation
import SwiftProtobuf

/// A stream of 2,000 varint-delimited users (roadmap 0009): AemiProtobuf's frames against swift-protobuf's `BinaryDelimited`.
func registerFramingBenchmarks() {
    let c = corpusCodecs(2_000)
    let encoder = ProtobufEncoder()
    let decoder = ProtobufDecoder()
    var stream: [UInt8] = []
    for user in c.protoUsers.users {
        stream += (try? encoder.encodeFrameToBytes(user, format: .varintDelimited)) ?? []
    }
    let streamData = Data(stream)

    Benchmark("framing/varintDelimited/write/pb.AemiProtobuf.fast") { bm in
        for _ in bm.scaledIterations {
            var out: [UInt8] = []
            for user in c.protoUsers.users { out += try encoder.encodeFrameToBytes(user, format: .varintDelimited) }
            blackHole(out)
        }
    }
    Benchmark("framing/varintDelimited/write/pb.SwiftProtobuf") { bm in
        for _ in bm.scaledIterations {
            let output = OutputStream.toMemory()
            output.open()
            for user in c.swiftProtobufUsers.users { try BinaryDelimited.serialize(message: user, to: output) }
            output.close()
            blackHole(output.property(forKey: .dataWrittenToMemoryStreamKey))
        }
    }
    Benchmark("framing/varintDelimited/read/pb.AemiProtobuf.fast") { bm in
        for _ in bm.scaledIterations {
            var frames = FrameDecoder(format: .varintDelimited)
            frames.push(stream)
            var count = 0
            while let frame = try frames.next() {
                blackHole(try decoder.decode(ProtoUser.self, frame: frame))
                count += 1
            }
            precondition(count == 2_000)
        }
    }
    Benchmark("framing/varintDelimited/read/pb.SwiftProtobuf") { bm in
        for _ in bm.scaledIterations {
            let input = InputStream(data: streamData)
            input.open()
            var count = 0
            while input.hasBytesAvailable,
                let user = try? BinaryDelimited.parse(messageType: User.self, from: input)
            {
                blackHole(user)
                count += 1
            }
            input.close()
            precondition(count == 2_000)
        }
    }
}
