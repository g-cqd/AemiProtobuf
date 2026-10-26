public struct FieldDescriptor: Sendable, Equatable {
    public var name: String
    public var number: Int32
    public var label: FieldLabel
    public var type: FieldType
    public var typeName: String
    public var jsonName: String
    /// Index into the enclosing message's ``MessageDescriptor/oneofs``; `nil` when the field is in no oneof.
    public var oneofIndex: Int32?
    /// Whether a proto3 field was declared `optional` (explicit presence, held in a synthetic oneof).
    public var proto3Optional: Bool

    public init(
        name: String = "", number: Int32 = 0, label: FieldLabel = .optional,
        type: FieldType = .int32, typeName: String = "", jsonName: String = "",
        oneofIndex: Int32? = nil, proto3Optional: Bool = false
    ) {
        self.name = name
        self.number = number
        self.label = label
        self.type = type
        self.typeName = typeName
        self.jsonName = jsonName
        self.oneofIndex = oneofIndex
        self.proto3Optional = proto3Optional
    }
}
