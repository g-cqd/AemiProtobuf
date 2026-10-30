/// Gathers the definitions of types and of everything they refer to into one `.proto` file (roadmap 0005).
public enum ProtoDefinitions {
    /// An edition-2023 file declaring `types` and every type they reach, each once, in the order they are reached.
    /// - Throws: ``ProtoDefinitionError/undefined(_:)`` for a type with no definition, ``ProtoDefinitionError/duplicateName(_:)``
    ///   when two types declare one name (definitions name types by their own name, not their enclosing ones).
    public static func file(for types: [Any.Type], package: String = "") throws(ProtoDefinitionError) -> String {
        var definitions: [String] = []
        var seen: Set<ObjectIdentifier> = []
        var names: [String: ObjectIdentifier] = [:]
        var queue = types
        var index = 0
        while index < queue.count {
            let type = queue[index]
            index += 1
            guard seen.insert(ObjectIdentifier(type)).inserted else { continue }
            if let oneof = type as? any AemiProtoOneof.Type {
                queue += oneof.__aepbOneofDependencies
                continue
            }
            guard let defined = type as? any AemiProtoDefined.Type else { throw .undefined(String(describing: type)) }
            if let other = names[defined.protoName], other != ObjectIdentifier(type) {
                throw .duplicateName(defined.protoName)
            }
            names[defined.protoName] = ObjectIdentifier(type)
            definitions.append(defined.protoDefinition)
            queue += defined.protoDependencies
        }
        let header = "edition = \"2023\";\n" + (package.isEmpty ? "" : "package \(package);\n")
        return header + "\n" + definitions.joined(separator: "\n")
    }

    /// `camelCase` or `PascalCase` as `UPPER_SNAKE`.
    public static func upperSnake(_ name: String) -> String {
        var out = ""
        for (index, character) in name.enumerated() {
            if character.isUppercase, index > 0, out.last != "_" { out.append("_") }
            out += character.uppercased()
        }
        return out
    }
}
