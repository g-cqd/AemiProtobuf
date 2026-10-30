public import AemiProtobufCore

/// Why ``DynamicSchema`` could not read or write a message.
public enum DynamicMessageError: Error, Sendable, Equatable {
    /// The bytes are not a valid encoding (the offsets count from the start of the input).
    case wire(WireError)
    /// The descriptor set has no message with this fully qualified name.
    case unknownMessageType(String)
    /// The message has a value for a number its type does not declare.
    case unknownField(message: String, number: Int32)
    /// The value's case is not the field's type (`.string` for an `int32` field).
    case typeMismatch(message: String, field: String)
}
