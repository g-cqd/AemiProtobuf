extension ProtoSourceWriter {
    static let scalarNames: [FieldType: String] = [
        .double: "double", .float: "float", .int64: "int64", .uint64: "uint64", .int32: "int32", .fixed64: "fixed64",
        .fixed32: "fixed32", .bool: "bool", .string: "string", .bytes: "bytes", .uint32: "uint32",
        .sfixed32: "sfixed32",
        .sfixed64: "sfixed64", .sint32: "sint32", .sint64: "sint64"
    ]

    /// Fields, extensions and nested messages in an order that keeps each list's order when compiled again: a group's or map's
    /// message is emitted with its field, every other nested message as soon as the messages before it are out.
    func members(
        fields: [FieldDescriptor], extensions: [FieldDescriptor], nested: [MessageDescriptor], scope: String,
        indent: Int,
        oneofs: [OneofDescriptor] = []
    ) -> [Work] {
        let prefix = scope.isEmpty ? "." : "." + scope + "."
        var owner: [Int: (isExtension: Bool, index: Int)] = [:]
        for (index, message) in nested.enumerated() {
            let full = prefix + message.name
            if let field = fields.firstIndex(where: { $0.typeName == full && ($0.type == .group || message.isMapEntry) }
            ) {
                owner[index] = (false, field)
            } else if let field = extensions.firstIndex(where: { $0.typeName == full && $0.type == .group }) {
                owner[index] = (true, field)
            }
        }
        var out: [Work] = []
        var nextField = 0
        var nextExtension = 0
        var printedOneofs: Set<Int32> = []
        func emitFields(through last: Int) {
            while nextField <= last, nextField < fields.count {
                let field = fields[nextField]
                if let oneof = field.oneofIndex, !field.proto3Optional, Int(oneof) < oneofs.count {
                    if printedOneofs.insert(oneof).inserted {
                        out.append(.line("oneof \(oneofs[Int(oneof)].name) {", indent: indent))
                        out += optionLines(oneofs[Int(oneof)].options, "OneofOptions", indent: indent + 1)
                        for member in fields where member.oneofIndex == oneof {
                            out += fieldWork(member, label: "", nested: nested, scope: scope, indent: indent + 1)
                        }
                        out.append(.line("}", indent: indent))
                    }
                } else {
                    out += fieldWork(field, label: label(field), nested: nested, scope: scope, indent: indent)
                }
                nextField += 1
            }
        }
        func emitExtensions(through last: Int) {
            while nextExtension <= last, nextExtension < extensions.count {
                let extendee = extensions[nextExtension].extendee
                out.append(.line("extend \(extendee) {", indent: indent))
                while nextExtension <= last, nextExtension < extensions.count,
                    extensions[nextExtension].extendee == extendee
                {
                    let field = extensions[nextExtension]
                    out += fieldWork(field, label: label(field), nested: nested, scope: scope, indent: indent + 1)
                    nextExtension += 1
                }
                out.append(.line("}", indent: indent))
            }
        }
        for (index, message) in nested.enumerated() {
            if let (isExtension, field) = owner[index] {
                if isExtension { emitExtensions(through: field) } else { emitFields(through: field) }
            } else {
                out.append(.message(message, scope: scope, header: "message \(message.name) {", indent: indent))
            }
        }
        emitFields(through: fields.count - 1)
        emitExtensions(through: extensions.count - 1)
        return out
    }

    private func label(_ field: FieldDescriptor) -> String {
        if field.label == .repeated { return "repeated " }
        if isProto3 { return field.proto3Optional ? "optional " : "" }
        if isEditions { return "" }
        return field.label == .required ? "required " : "optional "
    }

    /// A field's line, a map's line, or a group's header and body.
    private func fieldWork(
        _ field: FieldDescriptor, label: String, nested: [MessageDescriptor], scope: String, indent: Int
    )
        -> [Work]
    {
        let suffix = fieldOptions(field)
        let prefix = scope.isEmpty ? "." : "." + scope + "."
        if field.type == .group, let message = nested.first(where: { prefix + $0.name == field.typeName }) {
            let header = "\(label)group \(message.name) = \(field.number)\(suffix) {"
            return [.message(message, scope: scope, header: header, indent: indent)]
        }
        if field.label == .repeated,
            let entry = nested.first(where: { prefix + $0.name == field.typeName && $0.isMapEntry }),
            let key = entry.fields.first(where: { $0.number == 1 }),
            let value = entry.fields.first(where: { $0.number == 2 })
        {
            return [
                .line(
                    "map<\(typeText(key)), \(typeText(value))> \(field.name) = \(field.number)\(suffix);",
                    indent: indent)
            ]
        }
        return [.line("\(label)\(typeText(field)) \(field.name) = \(field.number)\(suffix);", indent: indent)]
    }

    private func typeText(_ field: FieldDescriptor) -> String { Self.scalarNames[field.type] ?? field.typeName }

    /// `[default = …, json_name = "…", options…]`, or nothing.
    private func fieldOptions(_ field: FieldDescriptor) -> String {
        var entries: [String] = []
        if let value = field.defaultValue {
            switch field.type {
                case .string: entries.append("default = " + ProtoLiteral.quoted(Array(value.utf8), keepUTF8: true))
                case .bytes: entries.append("default = \"" + value + "\"")
                default: entries.append("default = " + value)
            }
        }
        if field.extendee.isEmpty, field.jsonName != ProtoParser.jsonName(for: field.name) {
            entries.append("json_name = " + ProtoLiteral.quoted(Array(field.jsonName.utf8), keepUTF8: true))
        }
        entries += optionEntries(field.options, "FieldOptions").map { "\($0) = \($1)" }
        return entries.isEmpty ? "" : " [" + entries.joined(separator: ", ") + "]"
    }
}
