public import AemiProtobufCore

public struct EnumDescriptor: Sendable, Equatable {
    public var name: String
    public var values: [EnumValueDescriptor]
    /// `EnumOptions`, as protoc wrote them.
    public var options: [UInt8]?
    /// Reserved numbers, `end` included (unlike a message's).
    public var reservedRanges: [DescriptorRange] = []
    public var reservedNames: [String] = []
    public var unknownFields = UnknownFields()

    public init(name: String = "", values: [EnumValueDescriptor] = []) {
        self.name = name
        self.values = values
    }
}
