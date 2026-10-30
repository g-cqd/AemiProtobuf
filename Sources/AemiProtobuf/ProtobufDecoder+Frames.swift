public import AemiProtobufCore

extension ProtobufDecoder {
    /// The message in `frame`, decompressed first when the frame says it is compressed.
    public func decode<T: Decodable & AemiProtoFastDecodable>(
        _ type: T.Type, frame: Frame, compression: (any FrameCompression)? = nil
    ) throws -> T {
        guard frame.isCompressed else { return try decode(type, fromBytes: frame.payload) }
        guard let compression else {
            throw ProtobufDecodingError.unsupported("the frame is compressed and no compression was given")
        }
        return try decode(type, fromBytes: try compression.decompress(frame.payload))
    }

    /// The messages in a stream of byte chunks, one a frame: the shape of a gRPC server stream.
    public func messages<T: Decodable & AemiProtoFastDecodable & Sendable, Base: AsyncSequence>(
        of type: T.Type, from base: Base, format: FrameFormat, compression: (any FrameCompression)? = nil,
        maxFrameBytes: Int = 4 * 1_024 * 1_024
    ) -> ProtobufMessageSequence<T, Base> where Base.Element: Sequence<UInt8> {
        ProtobufMessageSequence(
            frames: FrameAsyncSequence(base, format: format, maxFrameBytes: maxFrameBytes), decoder: self,
            compression: compression)
    }
}
