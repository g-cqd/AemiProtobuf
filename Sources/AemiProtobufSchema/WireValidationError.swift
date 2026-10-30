public import AemiProtobufCore

/// A schema mismatch, malformed wire value, or incomplete validation result.
public enum WireValidationError: Error, Sendable, Equatable {
    /// The descriptor contains an invalid or duplicate field number.
    case invalidDescriptorNumber(Int32)
    /// No message has this name in the descriptor set.
    case unknownMessage(String)
    /// A message field's type name resolves to nothing in the descriptor set.
    case unresolvedType(field: Int32, typeName: String)
    /// Validation stopped after the configured number of findings.
    case findingLimitReached
    case unknownField(FieldNumber, at: Int)
    case unexpectedWireType(field: Int32, expected: WireType, actual: WireType, at: Int)
    case invalidUTF8(field: Int32, at: Int)
    case requiredFieldMissing(field: Int32, name: String)
    /// A closed enumeration's field holds a number the enumeration has no value for (strict mode; C++ keeps it as an unknown field).
    case unknownEnumValue(field: Int32, value: Int32, at: Int)
    case wireCorrupted(WireError)
}
