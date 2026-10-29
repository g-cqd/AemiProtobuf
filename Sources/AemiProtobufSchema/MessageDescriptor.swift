public import AemiProtobufCore

public struct MessageDescriptor: Sendable, Equatable {
    public var name: String
    public var fields: [FieldDescriptor]
    public var nestedMessages: [MessageDescriptor]
    public var nestedEnums: [EnumDescriptor]
    public var oneofs: [OneofDescriptor]
    public var extensionRanges: [DescriptorRange] = []
    /// Extensions declared inside the message.
    public var extensions: [FieldDescriptor] = []
    /// `MessageOptions`, as protoc wrote them.
    public var options: [UInt8]?
    public var reservedRanges: [DescriptorRange] = []
    public var reservedNames: [String] = []
    public var unknownFields = UnknownFields()

    public init(
        name: String = "", fields: [FieldDescriptor] = [],
        nestedMessages: [MessageDescriptor] = [], nestedEnums: [EnumDescriptor] = [],
        oneofs: [OneofDescriptor] = []
    ) {
        self.name = name
        self.fields = fields
        self.nestedMessages = nestedMessages
        self.nestedEnums = nestedEnums
        self.oneofs = oneofs
    }
}
