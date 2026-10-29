public import AemiProtobufCore
public import Foundation

/// Decodes protobuf wire bytes to `Decodable` values; the inverse of ``ProtobufEncoder``, with the same type mapping.
///
/// An absent field decodes to its proto3 default (`decodeIfPresent` gives `nil`); a singular field takes its last
/// occurrence; a nested message given twice is merged; repeated numbers decode packed, unpacked or mixed; unknown fields are
/// skipped. A wire value that does not match the requested type, an integer that does not fit it, bytes that are not UTF-8,
/// and every malformed or over-limit input throw. Nothing traps on any input.
///
/// Memory: a message's field index is one 24-byte entry per field occurrence, at most 12 times the message's size.
public struct ProtobufDecoder: Sendable {
    public var userInfo: [CodingUserInfoKey: any Sendable] = [:]
    public var limits: WireLimits

    public init(limits: WireLimits = .default) {
        self.limits = limits
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decode(type, fromBytes: [UInt8](data))
    }

    public func decode<T: Decodable>(_ type: T.Type, from bytes: [UInt8]) throws -> T {
        try decode(type, fromBytes: bytes)
    }

    /// A type that is only `Codable` keeps no unknown fields: it has nowhere to put them (ADR-0012). A `@ProtoMessage` takes the
    /// fast path and keeps them.
    /// - Throws: ``ProtobufDecodingError`` for malformed bytes, an exceeded limit or an unsupported construct,
    ///   `DecodingError` for a value that does not match the requested type, or whatever the type's `init(from:)` throws.
    /// - Complexity: O(bytes) per message level, so O(bytes × depth) for deeply nested input, with `depth` bounded by
    ///   `limits.maxDepth`.
    public func decode<T: Decodable>(_ type: T.Type, fromBytes bytes: [UInt8]) throws -> T {
        if let fast = type as? any AemiProtoFastDecodable.Type {
            guard let decoded = try decodeFast(fast, bytes) as? T else {
                throw ProtobufDecodingError.unsupported("\(T.self) is not the type its fast path decodes")
            }
            return decoded
        }
        let context = _ProtobufDecodeContext(bytes: bytes, limits: limits, userInfo: userInfo)
        let root = _ProtobufDecoderImpl(
            context: context, source: .message(ranges: [0 ..< bytes.count]), depth: 0, codingPath: [])
        return try T(from: root)
    }

    private func decodeFast<F: AemiProtoFastDecodable>(_ type: F.Type, _ bytes: [UInt8]) throws -> F {
        do throws(WireError) {
            return try WireReader.withReader(over: bytes, limits: limits) { r throws(WireError) in
                try F.__aepbDecode(from: &r)
            }
        } catch {
            throw ProtobufDecodingError.underlying(error)
        }
    }

    /// Decodes a message that is only fast-path (no `Codable`), with no dynamic cast.
    /// - Throws: ``ProtobufDecodingError/underlying(_:)``.
    public func decode<T: AemiProtoFastDecodable>(_ type: T.Type, fromBytes bytes: [UInt8]) throws -> T {
        try decodeFast(type, bytes)
    }

    /// A message that is both `Codable` and fast-path, such as every `@ProtoMessage`: the fast path, chosen at compile time.
    public func decode<T: Decodable & AemiProtoFastDecodable>(_ type: T.Type, fromBytes bytes: [UInt8]) throws -> T {
        try decodeFast(type, bytes)
    }

    /// Decodes a fast-path message from `Data`. Borrowing the `Data`'s storage instead of copying it was measured and was no
    /// faster: the same speed at 238 KB, and 170 ns slower for a 10-field message.
    public func decode<T: AemiProtoFastDecodable>(_ type: T.Type, from data: Data) throws -> T {
        try decodeFast(type, [UInt8](data))
    }

    public func decode<T: Decodable & AemiProtoFastDecodable>(_ type: T.Type, from data: Data) throws -> T {
        try decodeFast(type, [UInt8](data))
    }
}
