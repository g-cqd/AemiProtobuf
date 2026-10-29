import AemiProtobufSchema

/// The Swift spelling of one field: its type, its `@ProtoField` arguments, its default (roadmap 0028).
struct FieldPlanner {
    let symbols: SymbolTable
    let recursion: RecursionAnalysis

    /// A field's Swift element type and the kind argument it needs (`nil` when the macro infers it from the type).
    func scalar(_ field: FieldDescriptor, delimited: Bool) throws(GeneratorError) -> (type: String, kind: String?) {
        switch field.type {
            case .double: ("Double", nil)
            case .float: ("Float", nil)
            case .int64: ("Int64", nil)
            case .uint64: ("UInt64", nil)
            case .int32: ("Int32", nil)
            case .fixed64: ("UInt64", ".fixed64")
            case .fixed32: ("UInt32", ".fixed32")
            case .bool: ("Bool", nil)
            case .string: ("String", nil)
            case .bytes: ("[UInt8]", nil)
            case .uint32: ("UInt32", nil)
            case .sfixed32: ("Int32", ".sfixed32")
            case .sfixed64: ("Int64", ".sfixed64")
            case .sint32: ("Int32", ".sint32")
            case .sint64: ("Int64", ".sint64")
            case .enum: (try swiftName(field.typeName), ".enumeration")
            case .group: (try swiftName(field.typeName), ".group")
            case .message: (try swiftName(field.typeName), delimited ? ".group" : nil)
        }
    }

    func swiftName(_ typeName: String) throws(GeneratorError) -> String {
        guard let symbol = symbols[typeName] else { throw .unknownType(typeName) }
        return symbol.swiftName
    }

    /// Whether a message-typed field is written between group tags: a proto2 group, or `message_encoding = DELIMITED`.
    func isDelimited(_ field: FieldDescriptor, _ features: ResolvedFeatures) -> Bool {
        field.type == .group || (field.type == .message && features.messageEncoding == 2)
    }

    /// The property declaration of a field that is not in a oneof.
    func declaration(
        _ field: FieldDescriptor, owner: String, features inherited: ResolvedFeatures, name: String, access: String
    ) throws(GeneratorError) -> String {
        let features = inherited.merged(field.features)
        if field.label == .repeated, let entry = symbols.message(field.typeName), entry.isMapEntry {
            return try map(field, entry, name: name, access: access)
        }
        let delimited = isDelimited(field, features)
        let (type, kind) = try scalar(field, delimited: delimited)
        var arguments = ["\(field.number)"]
        if let kind { arguments.append(kind) }
        if field.label == .repeated {
            if isPackable(field.type), !packs(field, features) { arguments.append("packed: false") }
            return "@ProtoField(\(arguments.joined(separator: ", "))) \(access)var \(name): [\(type)] = []"
        }
        let isMessage = field.type == .message || field.type == .group
        let required = field.label == .required || features.fieldPresence == 3
        let explicit = isMessage || required || field.proto3Optional || features.fieldPresence == 1
        if required { arguments.append("required: true") }
        let attribute = "@ProtoField(\(arguments.joined(separator: ", ")))"
        guard explicit else {
            return "\(attribute) \(access)var \(name): \(type) = \(try implicitDefault(field, type))"
        }
        let indirect = isMessage && recursion.needsIndirection(owner: owner, target: field.typeName) ? " @Indirect" : ""
        return "\(attribute)\(indirect) \(access)var \(name): \(type)? = nil"
    }

    private func map(
        _ field: FieldDescriptor, _ entry: MessageDescriptor, name: String, access: String
    ) throws(GeneratorError) -> String {
        guard let keyField = entry.fields.first(where: { $0.number == 1 }),
            let valueField = entry.fields.first(where: { $0.number == 2 })
        else { throw .unknownType(field.typeName) }
        let key = try scalar(keyField, delimited: false)
        let value = try scalar(valueField, delimited: false)
        var arguments = ["\(field.number)"]
        if let kind = key.kind { arguments.append("key: \(kind)") }
        if let kind = value.kind { arguments.append("value: \(kind)") }
        return
            "@ProtoField(\(arguments.joined(separator: ", "))) \(access)var \(name): [\(key.type): \(value.type)] = [:]"
    }

    private func isPackable(_ type: FieldType) -> Bool {
        ![.string, .bytes, .message, .group].contains(type)
    }

    /// proto2 packs only what says `[packed = true]`, proto3 all but what says `[packed = false]`, editions follow
    /// `repeated_field_encoding`.
    private func packs(_ field: FieldDescriptor, _ features: ResolvedFeatures) -> Bool {
        if let packed = field.packed { return packed }
        return features.repeatedFieldEncoding == 1
    }

    /// The zero of an implicit-presence field.
    private func implicitDefault(_ field: FieldDescriptor, _ type: String) throws(GeneratorError) -> String {
        switch field.type {
            case .bool: "false"
            case .string: "\"\""
            case .bytes: "[]"
            case .enum: "\(type)(rawValue: 0)"
            default: "0"
        }
    }
}
