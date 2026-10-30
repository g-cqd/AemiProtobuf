/// A descriptor set with every message and enum, nested ones included, under its fully qualified name.
struct FlatSchema {
    var messages: [String: MessageDescriptor] = [:]
    var enums: [String: EnumDescriptor] = [:]
    /// The values of every closed enumeration (proto2, or `enum_type = CLOSED`), by fully qualified name.
    var closedEnumValues: [String: Set<Int32>] = [:]
    /// Extensions by the fully qualified name (no leading dot) of the message they extend.
    var extensions: [String: [FieldDescriptor]] = [:]
    /// The features in force in each message: its file's, every enclosing message's, then its own.
    var messageFeatures: [String: ResolvedFeatures] = [:]

    /// Walks the set with an explicit work list (no recursion).
    /// - Complexity: O(messages + enums).
    init(_ set: FileDescriptorSet) {
        var pending: [(String, MessageDescriptor, FileDescriptor, ResolvedFeatures)] = []
        for file in set.files {
            let scope = file.package.isEmpty ? "" : file.package + "."
            let features = ResolvedFeatures.of(file)
            pending.append(contentsOf: file.messages.map { (scope + $0.name, $0, file, features) })
            for e in file.enums { add(e, named: scope + e.name, in: file) }
            for field in file.extensions {
                extensions[String(field.extendee.drop { $0 == "." }), default: []].append(field)
            }
        }
        while let (name, message, file, enclosing) = pending.popLast() {
            messages[name] = message
            let features = enclosing.merged(message.features)
            messageFeatures[name] = features
            pending.append(contentsOf: message.nestedMessages.map { (name + "." + $0.name, $0, file, features) })
            for e in message.nestedEnums { add(e, named: name + "." + e.name, in: file) }
            for field in message.extensions {
                extensions[String(field.extendee.drop { $0 == "." }), default: []].append(field)
            }
        }
    }

    /// An enumeration is closed in a proto2 file, or when its features or its file's say `enum_type = CLOSED` (2).
    private mutating func add(_ enumeration: EnumDescriptor, named name: String, in file: FileDescriptor) {
        enums[name] = enumeration
        let type = enumeration.features?.enumType ?? file.features?.enumType
        let closed = type.map { $0 == 2 } ?? (file.resolvedSyntax == "proto2")
        if closed { closedEnumValues[name] = Set(enumeration.values.map(\.number)) }
    }
}
