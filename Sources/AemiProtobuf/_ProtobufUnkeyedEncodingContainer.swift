import AemiProtobufCore
import Foundation

/// Writes the elements of one repeated field. Numeric elements join one packed run; strings, bytes and messages are written
/// one tagged record each, as proto3 does.
struct _ProtobufUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let encoder: _ProtobufEncoderImpl
    var codingPath: [any CodingKey] { encoder.codingPath }
    var count: Int { encoder.elementCount }

    private func packed(_ scalar: _WireScalar) throws {
        try encoder.appendPacked(scalar)
        guard encoder.packed.count <= encoder.state.limits.maxMessageBytes else {
            let error = ProtobufEncodingError.underlying(.messageTooLarge(limit: encoder.state.limits.maxMessageBytes))
            encoder.state.fail(error)
            throw error
        }
    }

    private func record(_ body: (inout WireWriter, FieldNumber) -> Void) throws {
        guard let field = encoder.field else {
            throw ProtobufEncodingError.unsupported("a repeated value needs a field")
        }
        try encoder.state.perform { w throws(WireError) in body(&w, field) }
        encoder.noteElement()
    }

    mutating func encodeNil() throws {}
    mutating func encode(_ value: Bool) throws { try packed(.varint(value ? 1 : 0)) }
    mutating func encode(_ value: Double) throws { try packed(.fixed64(value.bitPattern)) }
    mutating func encode(_ value: Float) throws { try packed(.fixed32(value.bitPattern)) }
    mutating func encode(_ value: Int) throws { try packed(.signed(Int64(value))) }
    mutating func encode(_ value: Int8) throws { try packed(.signed(Int64(value))) }
    mutating func encode(_ value: Int16) throws { try packed(.signed(Int64(value))) }
    mutating func encode(_ value: Int32) throws { try packed(.signed(Int64(value))) }
    mutating func encode(_ value: Int64) throws { try packed(.signed(value)) }
    mutating func encode(_ value: UInt) throws { try packed(.varint(UInt64(value))) }
    mutating func encode(_ value: UInt8) throws { try packed(.varint(UInt64(value))) }
    mutating func encode(_ value: UInt16) throws { try packed(.varint(UInt64(value))) }
    mutating func encode(_ value: UInt32) throws { try packed(.varint(UInt64(value))) }
    mutating func encode(_ value: UInt64) throws { try packed(.varint(value)) }

    mutating func encode(_ value: String) throws {
        try record { w, field in
            w.appendTag(field, .lengthDelimited)
            w.appendString(value)
        }
    }

    /// The element as `type`; the caller has just matched `T.self`, so a mismatch is an internal error, thrown not trapped.
    private func element<T: Encodable, S>(_ value: T, as type: S.Type) throws -> S {
        guard let typed = value as? S else { throw ProtobufEncodingError.unsupported("\(T.self) is not \(S.self)") }
        return typed
    }

    /// Array calls the generic `encode` for each element; numbers must still join the packed run. The metatype is compared
    /// by identity, because a runtime `as?` chain costs more than the encoding of the element.
    private func encodeScalar<T: Encodable>(_ value: T) throws -> Bool {
        switch ObjectIdentifier(T.self) {
            case ObjectIdentifier(Bool.self): try packed(.varint(element(value, as: Bool.self) ? 1 : 0))
            case ObjectIdentifier(Double.self): try packed(.fixed64(element(value, as: Double.self).bitPattern))
            case ObjectIdentifier(Float.self): try packed(.fixed32(element(value, as: Float.self).bitPattern))
            case ObjectIdentifier(Int.self): try packed(.signed(Int64(element(value, as: Int.self))))
            case ObjectIdentifier(Int8.self): try packed(.signed(Int64(element(value, as: Int8.self))))
            case ObjectIdentifier(Int16.self): try packed(.signed(Int64(element(value, as: Int16.self))))
            case ObjectIdentifier(Int32.self): try packed(.signed(Int64(element(value, as: Int32.self))))
            case ObjectIdentifier(Int64.self): try packed(.signed(element(value, as: Int64.self)))
            case ObjectIdentifier(UInt.self): try packed(.varint(UInt64(element(value, as: UInt.self))))
            case ObjectIdentifier(UInt8.self): try packed(.varint(UInt64(element(value, as: UInt8.self))))
            case ObjectIdentifier(UInt16.self): try packed(.varint(UInt64(element(value, as: UInt16.self))))
            case ObjectIdentifier(UInt32.self): try packed(.varint(UInt64(element(value, as: UInt32.self))))
            case ObjectIdentifier(UInt64.self): try packed(.varint(element(value, as: UInt64.self)))
            case ObjectIdentifier(String.self):
                let string = try element(value, as: String.self)
                try record { w, field in
                    w.appendTag(field, .lengthDelimited)
                    w.appendString(string)
                }
            default: return false
        }
        return true
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        if try encodeScalar(value) { return }
        if let data = value as? Data { return try encodeBytes([UInt8](data)) }
        if let bytes = value as? [UInt8] { return try encodeBytes(bytes) }
        guard let field = encoder.field else {
            throw ProtobufEncodingError.unsupported("a repeated value needs a field")
        }
        let child = _ProtobufEncoderImpl(
            state: encoder.state, codingPath: codingPath, userInfo: encoder.userInfo, field: field, writesDefaults: true
        )
        try value.encode(to: child)
        try child.finish()
        encoder.noteElement()
    }

    private func encodeBytes(_ bytes: [UInt8]) throws {
        try record { w, field in
            w.appendTag(field, .lengthDelimited)
            w.appendBytes(bytes)
        }
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<
        NestedKey
    > {
        encoder.state.fail(
            ProtobufEncodingError.unsupported("nestedContainer(keyedBy:) in an array; encode the element instead"))
        return KeyedEncodingContainer(_ProtobufKeyedEncodingContainer<NestedKey>(encoder: encoder))
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        encoder.state.fail(ProtobufEncodingError.unsupported("an array of arrays has no protobuf encoding"))
        return self
    }

    mutating func superEncoder() -> any Encoder {
        encoder.state.fail(ProtobufEncodingError.unsupported("superEncoder in an array"))
        return encoder
    }
}
