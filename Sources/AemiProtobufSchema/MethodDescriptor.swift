public import AemiProtobufCore

/// An `rpc` declaration.
public struct MethodDescriptor: Sendable, Equatable {
    public var name: String = ""
    public var inputType: String = ""
    public var outputType: String = ""
    /// `MethodOptions`, as protoc wrote them.
    public var options: [UInt8]?
    public var clientStreaming: Bool?
    public var serverStreaming: Bool?
    public var unknownFields = UnknownFields()

    public init() {}
}
