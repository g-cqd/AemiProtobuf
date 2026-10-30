public import NIOCore

/// A `ByteToMessageDecoder` that reads frames of `format` from a channel and passes on each one's message (roadmap 0014):
/// `ByteToMessageHandler(ProtobufFrameDecoder<Message>(format: .grpc))`. Payloads are read in place.
public struct ProtobufFrameDecoder<Message: AemiProtoFastDecodable>: ByteToMessageDecoder {
    public typealias InboundOut = Message

    public let format: FrameFormat
    public let maxFrameBytes: Int
    public let decoder: ProtobufDecoder

    public init(
        format: FrameFormat, maxFrameBytes: Int = 4 * 1_024 * 1_024, decoder: ProtobufDecoder = ProtobufDecoder()
    ) {
        self.format = format
        self.maxFrameBytes = maxFrameBytes
        self.decoder = decoder
    }

    public mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard
            let message = try buffer.readProtobuf(
                Message.self, format: format, decoder: decoder, maxFrameBytes: maxFrameBytes)
        else { return .needMoreData }
        context.fireChannelRead(Self.wrapInboundOut(message))
        return .continue
    }

    /// At the end of the stream, frames still buffered are decoded; a partial frame is an error.
    public mutating func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws
        -> DecodingState
    {
        while try decode(context: context, buffer: &buffer) == .continue {}
        if buffer.readableBytes > 0 { throw FrameError.truncated(buffered: buffer.readableBytes) }
        return .needMoreData
    }
}
