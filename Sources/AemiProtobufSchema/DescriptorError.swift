public import AemiProtobufCore

/// Why a descriptor set was refused.
public enum DescriptorError: Error, Sendable, Equatable {
    /// The bytes are not well-formed protobuf.
    case wire(WireError)
    /// A field's `oneof_index` is negative or not below the message's oneof count.
    case oneofIndexOutOfRange(message: String, field: String, index: Int32)
}
