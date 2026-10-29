public import AemiProtobufCore

public struct FileDescriptor: Sendable, Equatable {
    public var name: String
    public var package: String
    public var syntax: String
    public var messages: [MessageDescriptor]
    public var enums: [EnumDescriptor]
    public var dependencies: [String] = []
    public var publicDependencies: [Int32] = []
    public var weakDependencies: [Int32] = []
    public var services: [ServiceDescriptor] = []
    /// Extensions declared at the top level of the file.
    public var extensions: [FieldDescriptor] = []
    /// `FileOptions`, as protoc wrote them.
    public var options: [UInt8]?
    /// `SourceCodeInfo`, as protoc wrote it (only with `--include_source_info`).
    public var sourceCodeInfo: [UInt8]?
    /// The `Edition` number of an editions file (2023 is 1000).
    public var edition: Int32?
    /// Fields of `FileDescriptorProto` this model does not hold, kept as read.
    public var unknownFields = UnknownFields()

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
