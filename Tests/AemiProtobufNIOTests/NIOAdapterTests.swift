import AemiProtobufNIO
import NIOCore
import NIOEmbedded
import Testing

/// Roadmap 0014: protobuf over swift-nio. A message read from a `ByteBuffer` in place, written into one, framed (varint or
/// gRPC) a piece at a time, and carried through a channel pipeline by the frame handlers.
@Suite struct NIOAdapterTests {
    private let sample = NIOPerson(id: 7, name: "Ada", tags: ["x", "y"])

    @Test func `a message is read from a buffer and written into one`() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        let written = try buffer.writeProtobuf(sample)
        #expect(written == buffer.readableBytes)
        #expect(try ProtobufDecoder().decode(NIOPerson.self, from: buffer) == sample)
        #expect(buffer.readableBytes == written)  // reading did not consume
    }

    @Test(arguments: [FrameFormat.varintDelimited, .grpc])
    func `frames are read only once whole, a byte at a time`(format: FrameFormat) throws {
        var stream = ByteBufferAllocator().buffer(capacity: 64)
        try stream.writeProtobufFrame(sample, format: format)
        try stream.writeProtobufFrame(NIOPerson(id: 8), format: format)
        var incoming = ByteBufferAllocator().buffer(capacity: 64)
        var decoded: [NIOPerson] = []
        while let byte = stream.readInteger(as: UInt8.self) {
            incoming.writeInteger(byte)
            if let message = try incoming.readProtobuf(NIOPerson.self, format: format) { decoded.append(message) }
        }
        #expect(decoded == [sample, NIOPerson(id: 8)])
        #expect(incoming.readableBytes == 0)
    }

    @Test func `a frame past the limit or with a bad flag is refused`() throws {
        var grpc = ByteBufferAllocator().buffer(capacity: 8)
        grpc.writeBytes([0x02, 0, 0, 0, 1, 0])
        #expect(throws: FrameError.self) { try grpc.readProtobufFrame(format: .grpc) }
        var long = ByteBufferAllocator().buffer(capacity: 8)
        long.writeBytes([0xFF, 0xFF, 0xFF, 0x7F])
        #expect(throws: FrameError.self) { try long.readProtobufFrame(format: .varintDelimited, maxFrameBytes: 1_024) }
    }

    @Test func `the handlers carry messages through a channel`() throws {
        let channel = EmbeddedChannel()
        try channel.pipeline.syncOperations.addHandler(
            ByteToMessageHandler(ProtobufFrameDecoder<NIOPerson>(format: .grpc)))
        try channel.pipeline.syncOperations.addHandler(
            MessageToByteHandler(ProtobufFrameEncoder<NIOPerson>(format: .grpc)))
        try channel.writeOutbound(sample)
        let framed = try #require(try channel.readOutbound(as: ByteBuffer.self))
        try channel.writeInbound(framed)
        #expect(try channel.readInbound(as: NIOPerson.self) == sample)
        #expect(try channel.finish().isClean)
    }
}
