public import AemiProtobufCore

public struct EnumValueDescriptor: Sendable, Equatable {
    public var name: String
    public var number: Int32
    /// `EnumValueOptions`, as protoc wrote them.
    public var options: [UInt8]?
    public var unknownFields = UnknownFields()

    public init(name: String = "", number: Int32 = 0) {
        self.name = name
        self.number = number
    }
}
