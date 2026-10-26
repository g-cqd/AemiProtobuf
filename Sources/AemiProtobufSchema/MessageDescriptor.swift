public struct MessageDescriptor: Sendable, Equatable {
    public var name: String
    public var fields: [FieldDescriptor]
    public var nestedMessages: [MessageDescriptor]
    public var nestedEnums: [EnumDescriptor]
    public var oneofs: [OneofDescriptor]

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
