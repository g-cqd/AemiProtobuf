public import NIOCore

/// A `MessageToByteEncoder` that writes each outbound message in a frame of `format` (roadmap 0014):
/// `MessageToByteHandler(ProtobufFrameEncoder<Message>(format: .grpc))`.
public struct ProtobufFrameEncoder<Message: AemiProtoFastEncodable>: MessageToByteEncoder {
    public typealias OutboundIn = Message

    public let format: FrameFormat
    public let encoder: ProtobufEncoder

    public init(format: FrameFormat, encoder: ProtobufEncoder = ProtobufEncoder()) {
        self.format = format
        self.encoder = encoder
    }

    public func encode(data: Message, out: inout ByteBuffer) throws {
        try out.writeProtobufFrame(data, format: format, encoder: encoder)
    }
}
