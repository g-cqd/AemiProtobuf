import AemiProtobufCore
import Foundation

/// Writes the fields of one message. A non-optional field holding its default is left out (proto3); an optional field that
/// is present is always written, so `0` and `""` survive as set values.
struct _ProtobufKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K
    let encoder: _ProtobufEncoderImpl
    var codingPath: [any CodingKey] { encoder.codingPath }

    // MARK: Shared writers

    private func put(_ scalar: _WireScalar, _ key: K, always: Bool) throws {
        let number = try _ProtobufFieldKey.number(for: key)
        guard always || !scalar.isDefault else { return }
        try encoder.state.perform { w throws(WireError) in
            w.appendTag(number, scalar.wireType)
            scalar.write(to: &w)
        }
    }

    private func putString(_ value: String, _ key: K, always: Bool) throws {
        let number = try _ProtobufFieldKey.number(for: key)
        guard always || !value.isEmpty else { return }
        try encoder.state.perform { w throws(WireError) in
            w.appendTag(number, .lengthDelimited)
            w.appendString(value)
        }
    }

    private func putBytes(_ value: [UInt8], _ key: K, always: Bool) throws {
        let number = try _ProtobufFieldKey.number(for: key)
        guard always || !value.isEmpty else { return }
        try encoder.state.perform { w throws(WireError) in
            w.appendTag(number, .lengthDelimited)
            w.appendBytes(value)
        }
    }

    private func putValue<T: Encodable>(_ value: T, _ key: K, always: Bool) throws {
        if let data = value as? Data { return try putBytes([UInt8](data), key, always: always) }
        if let bytes = value as? [UInt8] { return try putBytes(bytes, key, always: always) }
        let number = try _ProtobufFieldKey.number(for: key)
        if let fast = value as? any AemiProtoFastEncodable, !(value is any Sequence) {
            try encoder.state.perform { w throws(WireError) in
                try w.appendMessage(field: number) { w throws(WireError) in try fast.__aepbEncode(into: &w) }
            }
            return
        }
        let child = encoder.child(key, field: number, writesDefaults: always)
        try value.encode(to: child)
        try child.finish()
    }

    // MARK: Required

    mutating func encodeNil(forKey key: K) throws {}
    mutating func encode(_ value: Bool, forKey key: K) throws { try put(.varint(value ? 1 : 0), key, always: false) }
    mutating func encode(_ value: String, forKey key: K) throws { try putString(value, key, always: false) }
    mutating func encode(_ value: Double, forKey key: K) throws {
        try put(.fixed64(value.bitPattern), key, always: false)
    }
    mutating func encode(_ value: Float, forKey key: K) throws {
        try put(.fixed32(value.bitPattern), key, always: false)
    }
    mutating func encode(_ value: Int, forKey key: K) throws { try put(.signed(Int64(value)), key, always: false) }
    mutating func encode(_ value: Int8, forKey key: K) throws { try put(.signed(Int64(value)), key, always: false) }
    mutating func encode(_ value: Int16, forKey key: K) throws { try put(.signed(Int64(value)), key, always: false) }
    mutating func encode(_ value: Int32, forKey key: K) throws { try put(.signed(Int64(value)), key, always: false) }
    mutating func encode(_ value: Int64, forKey key: K) throws { try put(.signed(value), key, always: false) }
    mutating func encode(_ value: UInt, forKey key: K) throws { try put(.varint(UInt64(value)), key, always: false) }
    mutating func encode(_ value: UInt8, forKey key: K) throws { try put(.varint(UInt64(value)), key, always: false) }
    mutating func encode(_ value: UInt16, forKey key: K) throws { try put(.varint(UInt64(value)), key, always: false) }
    mutating func encode(_ value: UInt32, forKey key: K) throws { try put(.varint(UInt64(value)), key, always: false) }
    mutating func encode(_ value: UInt64, forKey key: K) throws { try put(.varint(value), key, always: false) }
    mutating func encode<T: Encodable>(_ value: T, forKey key: K) throws { try putValue(value, key, always: false) }

    // MARK: Optional fields: present means written

    mutating func encodeIfPresent(_ value: Bool?, forKey key: K) throws {
        if let value { try put(.varint(value ? 1 : 0), key, always: true) }
    }
    mutating func encodeIfPresent(_ value: String?, forKey key: K) throws {
        if let value { try putString(value, key, always: true) }
    }
    mutating func encodeIfPresent(_ value: Double?, forKey key: K) throws {
        if let value { try put(.fixed64(value.bitPattern), key, always: true) }
    }
    mutating func encodeIfPresent(_ value: Float?, forKey key: K) throws {
        if let value { try put(.fixed32(value.bitPattern), key, always: true) }
    }
    mutating func encodeIfPresent(_ value: Int?, forKey key: K) throws {
        if let value { try put(.signed(Int64(value)), key, always: true) }
    }
    mutating func encodeIfPresent(_ value: Int8?, forKey key: K) throws {
        if let value { try put(.signed(Int64(value)), key, always: true) }
    }
    mutating func encodeIfPresent(_ value: Int16?, forKey key: K) throws {
        if let value { try put(.signed(Int64(value)), key, always: true) }
    }
    mutating func encodeIfPresent(_ value: Int32?, forKey key: K) throws {
        if let value { try put(.signed(Int64(value)), key, always: true) }
    }
    mutating func encodeIfPresent(_ value: Int64?, forKey key: K) throws {
        if let value { try put(.signed(value), key, always: true) }
    }
    mutating func encodeIfPresent(_ value: UInt?, forKey key: K) throws {
        if let value { try put(.varint(UInt64(value)), key, always: true) }
    }
    mutating func encodeIfPresent(_ value: UInt8?, forKey key: K) throws {
        if let value { try put(.varint(UInt64(value)), key, always: true) }
    }
    mutating func encodeIfPresent(_ value: UInt16?, forKey key: K) throws {
        if let value { try put(.varint(UInt64(value)), key, always: true) }
    }
    mutating func encodeIfPresent(_ value: UInt32?, forKey key: K) throws {
        if let value { try put(.varint(UInt64(value)), key, always: true) }
    }
    mutating func encodeIfPresent(_ value: UInt64?, forKey key: K) throws {
        if let value { try put(.varint(value), key, always: true) }
    }
    mutating func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: K) throws {
        if let value { try putValue(value, key, always: true) }
    }

    // MARK: Unsupported: they would interleave a second message with this one

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type, forKey key: K
    ) -> KeyedEncodingContainer<NestedKey> {
        encoder.state.fail(
            ProtobufEncodingError.unsupported("nestedContainer(keyedBy:forKey:); encode the nested value instead"))
        return KeyedEncodingContainer(_ProtobufKeyedEncodingContainer<NestedKey>(encoder: encoder))
    }

    mutating func nestedUnkeyedContainer(forKey key: K) -> any UnkeyedEncodingContainer {
        encoder.state.fail(
            ProtobufEncodingError.unsupported("nestedUnkeyedContainer(forKey:); encode the array instead"))
        return _ProtobufUnkeyedEncodingContainer(encoder: encoder)
    }

    mutating func superEncoder() -> any Encoder { unsupportedSuper() }
    mutating func superEncoder(forKey key: K) -> any Encoder { unsupportedSuper() }

    private func unsupportedSuper() -> any Encoder {
        encoder.state.fail(ProtobufEncodingError.unsupported("superEncoder: class hierarchies are not messages"))
        return encoder
    }
}
