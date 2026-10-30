public import NIOCore

extension ByteBuffer {
    /// Appends `value`'s encoding, advancing the writer index.
    /// - Returns: the number of bytes written.
    @discardableResult
    public mutating func writeProtobuf<T: AemiProtoFastEncodable>(
        _ value: T, encoder: ProtobufEncoder = ProtobufEncoder()
    ) throws -> Int {
        writeBytes(try encoder.encodeToBytes(value))
    }

    /// Appends `value` in a frame of `format` (a varint length, or gRPC's flag and big-endian length).
    @discardableResult
    public mutating func writeProtobufFrame<T: AemiProtoFastEncodable>(
        _ value: T, format: FrameFormat, encoder: ProtobufEncoder = ProtobufEncoder()
    ) throws -> Int {
        writeBytes(FrameEncoder.frame(try encoder.encodeToBytes(value), format: format))
    }

    /// The next frame's payload, as a slice of this buffer (no copy), and whether it is compressed; the reader index moves past
    /// the frame. `nil`, with nothing read, until the whole frame has arrived.
    /// - Throws: ``FrameError/lengthExceedsLimit(declared:limit:at:)`` once a header declares more than `maxFrameBytes`,
    ///   ``FrameError/invalidFlag(_:at:)``, or ``FrameError/malformedLength(at:)``.
    public mutating func readProtobufFrame(
        format: FrameFormat, maxFrameBytes: Int = 4 * 1_024 * 1_024
    ) throws(FrameError) -> (payload: ByteBuffer, isCompressed: Bool)? {
        let start = readerIndex
        let header: (length: UInt64, size: Int, compressed: Bool)
        switch format {
            case .grpc:
                guard let flag = getInteger(at: start, as: UInt8.self),
                    let length = getInteger(at: start + 1, as: UInt32.self)
                else { return nil }
                guard flag & 0xFE == 0 else { throw .invalidFlag(flag, at: start) }
                header = (UInt64(length), 5, flag == 1)
            case .varintDelimited:
                guard let (length, size) = try varintPrefix(at: start) else { return nil }
                header = (length, size, false)
        }
        guard header.length <= UInt64(maxFrameBytes) else {
            throw .lengthExceedsLimit(declared: header.length, limit: maxFrameBytes, at: start)
        }
        guard let payload = getSlice(at: start + header.size, length: Int(header.length)) else { return nil }
        moveReaderIndex(forwardBy: header.size + Int(header.length))
        return (payload, header.compressed)
    }

    /// Reads the next whole frame of `format` and decodes its message; `nil`, with nothing read, until it has arrived.
    /// - Throws: a ``FrameError``, ``ProtobufDecodingError/unsupported(_:)`` for a compressed frame, or a decoding error.
    public mutating func readProtobuf<T: AemiProtoFastDecodable>(
        _ type: T.Type, format: FrameFormat, decoder: ProtobufDecoder = ProtobufDecoder(),
        maxFrameBytes: Int = 4 * 1_024 * 1_024
    ) throws -> T? {
        guard let frame = try readProtobufFrame(format: format, maxFrameBytes: maxFrameBytes) else { return nil }
        guard !frame.isCompressed else {
            throw ProtobufDecodingError.unsupported(
                "the frame is compressed; read it with readProtobufFrame and decompress it")
        }
        return try decoder.decode(type, from: frame.payload)
    }

    /// A varint length at `offset`: its value and its size, or `nil` while it is incomplete.
    private func varintPrefix(at offset: Int) throws(FrameError) -> (UInt64, Int)? {
        var value: UInt64 = 0
        var size = 0
        while true {
            guard let byte = getInteger(at: offset + size, as: UInt8.self) else { return nil }
            guard size < 10, size < 9 || byte <= 1 else { throw .malformedLength(at: offset) }
            value |= UInt64(byte & 0x7F) << UInt64(7 * size)
            size += 1
            if byte < 0x80 { return (value, size) }
        }
    }
}
