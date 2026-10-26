public struct EnumValueDescriptor: Sendable, Equatable {
    public var name: String
    public var number: Int32

    public init(name: String = "", number: Int32 = 0) {
        self.name = name
        self.number = number
    }
}
