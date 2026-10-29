public import AemiProtobufCore

/// A `service` declaration.
public struct ServiceDescriptor: Sendable, Equatable {
    public var name: String = ""
    public var methods: [MethodDescriptor] = []
    /// `ServiceOptions`, as protoc wrote them.
    public var options: [UInt8]?
    public var unknownFields = UnknownFields()

    public init() {}
}
