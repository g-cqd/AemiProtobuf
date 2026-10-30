import AemiProtobuf
import AemiProtobufCore
import Foundation
import Testing

/// Roadmap 0009: messages straight to and from frames, compressed or not, and a stream of them.
@Suite struct FramedCoderTests {
    private let leaf = Leaf(name: "framed")

    @Test(arguments: [FrameFormat.grpc, .varintDelimited])
    func `a message is framed as its bytes are, and reads back`(format: FrameFormat) throws {
        let payload = try ProtobufEncoder().encodeToBytes(leaf)
        let framed = try ProtobufEncoder().encodeFrameToBytes(leaf, format: format)
        #expect(framed == FrameEncoder.frame(payload, format: format))
        #expect(try ProtobufEncoder().encodeFrame(leaf, format: format) == Data(framed))
        var decoder = FrameDecoder(format: format)
        decoder.push(framed)
        let frame = try #require(try decoder.next())
        #expect(try ProtobufDecoder().decode(Leaf.self, frame: frame) == leaf)
    }

    @Test func `a compressed gRPC frame carries the flag and needs the compression to read`() throws {
        let framed = try ProtobufEncoder().encodeFrameToBytes(leaf, format: .grpc, compression: XorCompression())
        #expect(framed.first == 1)
        var decoder = FrameDecoder(format: .grpc)
        decoder.push(framed)
        let frame = try #require(try decoder.next())
        #expect(frame.isCompressed)
        #expect(try ProtobufDecoder().decode(Leaf.self, frame: frame, compression: XorCompression()) == leaf)
        #expect(throws: ProtobufDecodingError.self) { try ProtobufDecoder().decode(Leaf.self, frame: frame) }
    }

    @Test func `varint-delimited frames cannot say they are compressed`() {
        #expect(throws: ProtobufEncodingError.self) {
            try ProtobufEncoder().encodeFrameToBytes(leaf, format: .varintDelimited, compression: XorCompression())
        }
    }

    @Test func `a stream of frames split anywhere reads as its messages, and a bad one ends it with an error`()
        async throws
    {
        let leaves = [Leaf(name: "a"), Leaf(name: ""), Leaf(name: String(repeating: "c", count: 300))]
        var stream: [UInt8] = []
        for value in leaves { stream += try ProtobufEncoder().encodeFrameToBytes(value, format: .grpc) }
        for split in [1, 2, 7, stream.count] {
            let chunks = stride(from: 0, to: stream.count, by: split)
                .map { Array(stream[$0 ..< min($0 + split, stream.count)]) }
            var read: [Leaf] = []
            for try await value in ProtobufDecoder().messages(of: Leaf.self, from: chunks.async, format: .grpc) {
                read.append(value)
            }
            #expect(read == leaves, "chunks of \(split)")
        }
        let broken = [stream + FrameEncoder.grpc([0x0A, 0x05])]
        await #expect(throws: (any Error).self) {
            for try await _ in ProtobufDecoder().messages(of: Leaf.self, from: broken.async, format: .grpc) {}
        }
    }
}

extension Array where Element: Sendable {
    /// The elements as an async sequence, for the stream tests.
    fileprivate var async: AsyncStream<Element> {
        AsyncStream { continuation in
            for element in self { continuation.yield(element) }
            continuation.finish()
        }
    }
}
