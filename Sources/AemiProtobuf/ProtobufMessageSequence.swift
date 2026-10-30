public import AemiProtobufCore

/// Messages decoded from a stream of frames (``ProtobufDecoder/messages(of:from:format:compression:maxFrameBytes:)``). A frame
/// that does not decode ends the sequence with the error.
public struct ProtobufMessageSequence<T: Decodable & AemiProtoFastDecodable & Sendable, Base: AsyncSequence>:
    AsyncSequence
where Base.Element: Sequence<UInt8> {
    public typealias Element = T

    let frames: FrameAsyncSequence<Base>
    let decoder: ProtobufDecoder
    let compression: (any FrameCompression)?

    public func makeAsyncIterator() -> Iterator {
        Iterator(frames: frames.makeAsyncIterator(), decoder: decoder, compression: compression)
    }

    public struct Iterator: AsyncIteratorProtocol {
        var frames: FrameAsyncSequence<Base>.Iterator
        let decoder: ProtobufDecoder
        let compression: (any FrameCompression)?

        public mutating func next() async throws -> T? { nil }
    }
}
