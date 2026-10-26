import AemiProtobufCore
import Foundation

/// Writes one value as the field the encoder stands for: an enum's raw value, or a wrapper type's payload.
struct _ProtobufSingleValueEncodingContainer: SingleValueEncodingContainer {
    let encoder: _ProtobufEncoderImpl
    var codingPath: [any CodingKey] { encoder.codingPath }

    private func put(_ scalar: _WireScalar) throws {
        guard let field = encoder.field else { throw ProtobufEncodingError.unsupported("a top-level scalar") }
        guard encoder.writesDefaults || !scalar.isDefault else { return }
        try encoder.state.perform { w throws(WireError) in
            w.appendTag(field, scalar.wireType)
            scalar.write(to: &w)
        }
    }

    mutating func encodeNil() throws {}
    mutating func encode(_ value: Bool) throws { try put(.varint(value ? 1 : 0)) }
    mutating func encode(_ value: Double) throws { try put(.fixed64(value.bitPattern)) }
    mutating func encode(_ value: Float) throws { try put(.fixed32(value.bitPattern)) }
    mutating func encode(_ value: Int) throws { try put(.signed(Int64(value))) }
    mutating func encode(_ value: Int8) throws { try put(.signed(Int64(value))) }
    mutating func encode(_ value: Int16) throws { try put(.signed(Int64(value))) }
    mutating func encode(_ value: Int32) throws { try put(.signed(Int64(value))) }
    mutating func encode(_ value: Int64) throws { try put(.signed(value)) }
    mutating func encode(_ value: UInt) throws { try put(.varint(UInt64(value))) }
    mutating func encode(_ value: UInt8) throws { try put(.varint(UInt64(value))) }
    mutating func encode(_ value: UInt16) throws { try put(.varint(UInt64(value))) }
    mutating func encode(_ value: UInt32) throws { try put(.varint(UInt64(value))) }
    mutating func encode(_ value: UInt64) throws { try put(.varint(value)) }

    mutating func encode(_ value: String) throws {
        guard let field = encoder.field else { throw ProtobufEncodingError.unsupported("a top-level scalar") }
        guard encoder.writesDefaults || !value.isEmpty else { return }
        try encoder.state.perform { w throws(WireError) in
            w.appendTag(field, .lengthDelimited)
            w.appendString(value)
        }
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        guard encoder.field != nil else { throw ProtobufEncodingError.unsupported("a top-level scalar") }
        try value.encode(to: encoder)
    }
}
