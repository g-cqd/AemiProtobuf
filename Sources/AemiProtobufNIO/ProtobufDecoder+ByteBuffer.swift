public import NIOCore

extension ProtobufDecoder {
    /// Decodes a fast-path message from `buffer`'s readable bytes, in place (no copy); the reader index is not moved.
    /// - Throws: ``ProtobufDecodingError/underlying(_:)``.
    public func decode<T: AemiProtoFastDecodable>(_ type: T.Type, from buffer: ByteBuffer) throws -> T {
        try decodeInPlace(type, buffer)
    }

    /// The same for a message that is also `Codable`, such as every `@ProtoMessage`: the fast path, chosen at compile time.
    public func decode<T: Decodable & AemiProtoFastDecodable>(_ type: T.Type, from buffer: ByteBuffer) throws -> T {
        try decodeInPlace(type, buffer)
    }

    private func decodeInPlace<T: AemiProtoFastDecodable>(_ type: T.Type, _ buffer: ByteBuffer) throws -> T {
        do throws(WireError) {
            let decoded = try WireReader.withReader(over: buffer, limits: limits) { (reader) throws(WireError) in
                try T.__aepbDecode(from: &reader)
            }
            if let path = decoded.__aepbMissingRequired() { throw WireError.missingRequired(path) }
            return decoded
        } catch {
            throw ProtobufDecodingError.underlying(error)
        }
    }
}
