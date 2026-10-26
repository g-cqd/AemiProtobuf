public struct FileDescriptor: Sendable, Equatable {
    public var name: String
    public var package: String
    public var syntax: String
    public var messages: [MessageDescriptor]
    public var enums: [EnumDescriptor]

    public init(
        name: String = "", package: String = "", syntax: String = "proto3",
        messages: [MessageDescriptor] = [], enums: [EnumDescriptor] = []
    ) {
        self.name = name
        self.package = package
        self.syntax = syntax
        self.messages = messages
        self.enums = enums
    }
}
