public struct EnumDescriptor: Sendable, Equatable {
    public var name: String
    public var values: [EnumValueDescriptor]

    public init(name: String = "", values: [EnumValueDescriptor] = []) {
        self.name = name
        self.values = values
    }
}
