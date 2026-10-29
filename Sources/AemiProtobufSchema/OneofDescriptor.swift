public import AemiProtobufCore

/// A `oneof` declaration. Membership lives on the fields (``FieldDescriptor/oneofIndex``).
public struct OneofDescriptor: Sendable, Equatable {
    public var name: String
    /// `OneofOptions`, as protoc wrote them.
    public var options: [UInt8]?
    public var unknownFields = UnknownFields()

    public init(name: String = "") { self.name = name }
}
