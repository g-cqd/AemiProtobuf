public import AemiProtobufCore
public import Foundation

/// Encodes `Encodable` values to protobuf wire bytes.
///
/// A type that conforms to ``AemiProtoFastEncodable`` is written by its own code. Any other `Encodable` is written through
/// its `Codable` containers, which need the type to say what the schema cannot: its `CodingKey`s must have integer values,
/// the field numbers. Swift types map to wire types as below; `sint*`, `fixed*` and `sfixed*` have no Swift counterpart and
/// need the fast path or a descriptor.
///
/// | Swift | protobuf |
/// |---|---|
/// | `Int`, `Int8`...`Int64` | `int32`/`int64`, sign-extended |
/// | `UInt`, `UInt8`...`UInt64`, `Bool`, `RawRepresentable` integer enums | `uint32`/`uint64`, `bool`, `enum` (varint) |
/// | `Double`, `Float` | `double`, `float` |
/// | `String`, `Data`, `[UInt8]` | `string`, `bytes` |
/// | `[Number]`, `[Bool]`, `[Enum]` | `repeated`, packed |
/// | `[String]`, `[Data]`, `[Message]` | `repeated`, one record each |
/// | a `Codable` struct | a message, always written |
/// | `Optional` | explicit presence: a set zero or empty value is written |
///
/// A non-optional field holding its default (`0`, `""`, `false`, no elements) is left out, as proto3 does. Dictionaries,
/// nested containers, `superEncoder` and a top-level scalar or array throw ``ProtobufEncodingError/unsupported(_:)``.
public struct ProtobufEncoder: Sendable {
    public var userInfo: [CodingUserInfoKey: any Sendable] = [:]
    public var limits: WireLimits

    public init(limits: WireLimits = .default) {
        self.limits = limits
    }

    /// - Throws: ``ProtobufEncodingError``, or whatever the value's own `encode(to:)` throws.
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        Data(try encodeToBytes(value))
    }

    /// - Throws: ``ProtobufEncodingError`` for an unsupported construct, a coding key that is not a field number, or an
    ///   exceeded limit; or whatever the value's own `encode(to:)` throws.
    /// - Complexity: O(size of the encoding), plus one shift per nested message of 128 bytes or more.
    public func encodeToBytes<T: Encodable>(_ value: T) throws -> [UInt8] {
        if let fast = value as? any AemiProtoFastEncodable { return try fastBytes(fast) }
        let state = _ProtobufEncoderState(limits: limits)
        let root = _ProtobufEncoderImpl(state: state, codingPath: [], userInfo: userInfo)
        try value.encode(to: root)
        try root.finish()
        try state.check()
        return state.writer.bytes
    }

    /// Encodes a message that is only fast-path (no `Codable`). Takes the fast path with no dynamic cast.
    /// - Throws: ``ProtobufEncodingError/underlying(_:)``.
    public func encodeToBytes<T: AemiProtoFastEncodable>(_ value: T) throws -> [UInt8] {
        try fastBytes(value)
    }

    /// A message that is both `Codable` and fast-path, such as every `@ProtoMessage`: the fast path, chosen at compile time,
    /// with no dynamic cast. Without this overload such a call would be ambiguous between the two above.
    public func encodeToBytes<T: Encodable & AemiProtoFastEncodable>(_ value: T) throws -> [UInt8] {
        try fastBytes(value)
    }

    public func encode<T: AemiProtoFastEncodable>(_ value: T) throws -> Data {
        Data(try fastBytes(value))
    }

    public func encode<T: Encodable & AemiProtoFastEncodable>(_ value: T) throws -> Data {
        Data(try fastBytes(value))
    }

    /// Refuses a message without one of its proto2 `required` fields, as C++ does, then writes it.
    private func fastBytes<T: AemiProtoFastEncodable>(_ value: T) throws -> [UInt8] {
        if let path = value.__aepbMissingRequired() {
            throw ProtobufEncodingError.underlying(WireError.missingRequired(path))
        }
        var writer = WireWriter(limits: limits, reservingCapacity: 128)
        do throws(WireError) { try value.__aepbEncode(into: &writer) } catch {
            throw ProtobufEncodingError.underlying(error)
        }
        return writer.bytes
    }
}
