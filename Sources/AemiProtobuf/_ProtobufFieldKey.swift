import AemiProtobufCore

/// The field number a coding key stands for.
enum _ProtobufFieldKey {
    /// - Throws: ``ProtobufEncodingError/unsupportedCodingKeys(_:)`` for a key with no integer value or one that is not a
    ///   valid field number.
    static func number(for key: any CodingKey) throws -> FieldNumber {
        guard let value = key.intValue else {
            throw ProtobufEncodingError.unsupportedCodingKeys(
                "CodingKey '\(key.stringValue)' has no integer value for a protobuf field number")
        }
        guard let raw = UInt32(exactly: value), let number = FieldNumber(rawValue: raw) else {
            throw ProtobufEncodingError.unsupportedCodingKeys("CodingKey value \(value) is outside 1...536870911")
        }
        return number
    }
}
