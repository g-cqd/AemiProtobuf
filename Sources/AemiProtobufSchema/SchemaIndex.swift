/// The messages of a descriptor set by fully qualified name, and protobuf's rule for resolving a type name written in a field.
///
/// A name that starts with `.` is already fully qualified (what `protoc` writes). Any other is looked up from the innermost
/// scope outward: `Inner` in `pkg.Outer` is tried as `pkg.Outer.Inner`, then `pkg.Inner`, then `Inner`.
public struct SchemaIndex: Sendable {
    private var messages: [String: MessageDescriptor] = [:]
    private var enums: Set<String> = []
    private var closedEnums: [String: Set<Int32>] = [:]
    private var extensionFields: [String: [FieldDescriptor]] = [:]

    /// Indexes every message and enum, nested ones included.
    /// - Complexity: O(messages + enums).
    public init(_ set: FileDescriptorSet) {
        let flat = FlatSchema(set)
        messages = flat.messages
        enums = Set(flat.enums.keys)
        closedEnums = flat.closedEnumValues
        extensionFields = flat.extensions
    }

    /// The values of the closed enumeration with this fully qualified name; `nil` for an open one or none.
    public func closedEnumValues(named name: String) -> Set<Int32>? { closedEnums[name] }

    /// The extensions declared, anywhere in the set, for the message with this fully qualified name.
    public func extensions(of messageName: String) -> [FieldDescriptor] { extensionFields[messageName] ?? [] }

    /// The message with this fully qualified name (no leading dot).
    public func message(named name: String) -> MessageDescriptor? { messages[name] }

    /// The fully qualified name `typeName` denotes when written inside `scope` (the qualified name of the enclosing message), or
    /// `nil` if nothing has that name.
    public func resolve(_ typeName: String, in scope: String) -> String? {
        if typeName.hasPrefix(".") {
            let qualified = String(typeName.dropFirst())
            return messages[qualified] != nil || enums.contains(qualified) ? qualified : nil
        }
        var prefix = scope
        while true {
            let candidate = prefix.isEmpty ? typeName : prefix + "." + typeName
            if messages[candidate] != nil || enums.contains(candidate) { return candidate }
            guard let dot = prefix.lastIndex(of: ".") else {
                if prefix.isEmpty { return nil }
                prefix = ""
                continue
            }
            prefix = String(prefix[..<dot])
        }
    }
}
