/// A descriptor set with every message and enum, nested ones included, under its fully qualified name.
struct FlatSchema {
    var messages: [String: MessageDescriptor] = [:]
    var enums: [String: EnumDescriptor] = [:]
    /// The values of every closed enumeration (proto2, or `enum_type = CLOSED`), by fully qualified name.
    var closedEnumValues: [String: Set<Int32>] = [:]
    /// Extensions by the fully qualified name (no leading dot) of the message they extend.
    var extensions: [String: [FieldDescriptor]] = [:]
    /// Extensions with their scope, by the message they extend. Only with `resolvingFeatures`.
    var declaredExtensions: [String: [ExtensionDeclaration]] = [:]
    /// The features in force in each message: its file's, every enclosing message's, then its own. Only with `resolvingFeatures`.
    var messageFeatures: [String: ResolvedFeatures] = [:]

    /// Walks the set with an explicit work list (no recursion).
    /// - Complexity: O(messages + enums).
    /// - Parameters:
    ///   - set: the descriptor set.
    ///   - resolvingFeatures: whether to fill ``messageFeatures``, which reads every file's and message's options; the
    ///     validator and the comparator do without.
    init(_ set: FileDescriptorSet, resolvingFeatures: Bool = false) {
        var pending: [Pending] = []
        for file in set.files {
            let scope = file.package.isEmpty ? "" : file.package + "."
            let features = resolvingFeatures ? ResolvedFeatures.of(file) : .proto2
            pending.append(
                contentsOf: file.messages.map {
                    Pending(name: scope + $0.name, message: $0, file: file, features: features)
                })
            for e in file.enums { add(e, named: scope + e.name, in: file) }
            register(file.extensions, scope: file.package, features: features, declaring: resolvingFeatures)
        }
        while let next = pending.popLast() {
            let (name, message, file) = (next.name, next.message, next.file)
            messages[name] = message
            let features = resolvingFeatures ? next.features.merged(message.features) : next.features
            if resolvingFeatures { messageFeatures[name] = features }
            pending.append(
                contentsOf: message.nestedMessages.map {
                    Pending(name: name + "." + $0.name, message: $0, file: file, features: features)
                })
            for e in message.nestedEnums { add(e, named: name + "." + e.name, in: file) }
            register(message.extensions, scope: name, features: features, declaring: resolvingFeatures)
        }
    }

    /// Files each extension under the message it extends, and with `declaring`, with its scope.
    private mutating func register(
        _ fields: [FieldDescriptor], scope: String, features: ResolvedFeatures, declaring: Bool
    ) {
        for field in fields {
            let extendee = String(field.extendee.drop { $0 == "." })
            extensions[extendee, default: []].append(field)
            if declaring {
                declaredExtensions[extendee, default: []]
                    .append(ExtensionDeclaration(scope: scope, field: field, features: features))
            }
        }
    }

    /// A message still to index, with what it inherits.
    private struct Pending {
        let name: String
        let message: MessageDescriptor
        let file: FileDescriptor
        /// The features in force around it: its file's and its enclosing messages'.
        let features: ResolvedFeatures
    }

    /// An enumeration is closed in a proto2 file, or when its features or its file's say `enum_type = CLOSED` (2).
    private mutating func add(_ enumeration: EnumDescriptor, named name: String, in file: FileDescriptor) {
        enums[name] = enumeration
        let type = enumeration.features?.enumType ?? file.features?.enumType
        let closed = type.map { $0 == 2 } ?? (file.resolvedSyntax == "proto2")
        if closed { closedEnumValues[name] = Set(enumeration.values.map(\.number)) }
    }
}
