/// A `oneof` declaration. Membership lives on the fields (``FieldDescriptor/oneofIndex``).
public struct OneofDescriptor: Sendable, Equatable {
    public var name: String

    public init(name: String = "") { self.name = name }
}
