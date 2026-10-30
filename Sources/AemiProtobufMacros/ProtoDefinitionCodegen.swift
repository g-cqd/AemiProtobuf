/// The definition members (`AemiProtoDefined`, and a oneof's member lines): each field as an edition-2023 declaration
/// (roadmap 0005).
enum ProtoDefinitionCodegen {
    /// `protoName`, `protoDefinition` and `protoDependencies` for a message named `name`.
    static func message(_ name: String, _ fields: [ProtoFieldSpec]) -> [String] {
        var body = ["var lines = [\"message \(name) {\"]"]
        for field in fields {
            if field.shape == .oneof {
                body.append("lines.append(\"  oneof \(field.plainName) {\")")
                body.append("lines += \(field.swiftType).__aepbOneofDefinition.map { \"    \" + $0 }")
                body.append("lines.append(\"  }\")")
            } else {
                body.append("lines.append(\"  \(line(field));\")")
            }
        }
        body.append("lines.append(\"}\")")
        body.append("return lines.joined(separator: \"\\n\") + \"\\n\"")
        return [
            "static var protoName: String { \"\(name)\" }",
            "static var protoDefinition: String {\n" + body.joined(separator: "\n") + "\n}",
            "static var protoDependencies: [Any.Type] { [\(dependencies(fields))] }"
        ]
    }

    /// A oneof's member lines and the types they refer to.
    static func oneof(_ members: [ProtoFieldSpec]) -> [String] {
        let lines = members.map { "\"" + line($0) + ";\"" }.joined(separator: ", ")
        return [
            "static var __aepbOneofDefinition: [String] { [\(lines)] }",
            "static var __aepbOneofDependencies: [Any.Type] { [\(dependencies(members))] }"
        ]
    }

    /// `[repeated ]type name = number [options]`, or `map<K, V> name = number`.
    static func line(_ field: ProtoFieldSpec) -> String {
        let type = typeName(field.kind, field.swiftType)
        var options: [String] = []
        if field.kind == .group { options.append("features.message_encoding = DELIMITED") }
        var text = "\(type) \(field.plainName) = \(field.number)"
        switch field.shape {
            case .single where field.kind != .message && field.kind != .group:
                options.append("features.field_presence = IMPLICIT")
            case .optional where field.required: options.append("features.field_presence = LEGACY_REQUIRED")
            case .repeated:
                text = "repeated " + text
                if !field.packed, field.kind.isPackable {
                    options.append("features.repeated_field_encoding = EXPANDED")
                }
            case .map:
                let key = field.key.map { typeName($0.kind, $0.swiftType) } ?? "string"
                text = "map<\(key), \(type)> \(field.plainName) = \(field.number)"
            default: break
        }
        return options.isEmpty ? text : text + " [" + options.joined(separator: ", ") + "]"
    }

    /// The protobuf type of a kind: a scalar's name, or the referenced type's own name.
    private static func typeName(_ kind: ProtoKind, _ swiftType: String) -> String {
        switch kind {
            case .message, .group, .enumeration:
                String(swiftType.split(separator: ".").last ?? Substring(swiftType)).filter { $0 != "?" && $0 != "!" }
            default: kind.rawValue
        }
    }

    private static func dependencies(_ fields: [ProtoFieldSpec]) -> String {
        var types: [String] = []
        for field in fields where field.shape == .oneof || [.message, .group, .enumeration].contains(field.kind) {
            if !types.contains(field.swiftType) { types.append(field.swiftType) }
        }
        return types.map { "\($0).self" }.joined(separator: ", ")
    }
}
