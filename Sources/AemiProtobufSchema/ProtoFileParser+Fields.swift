import AemiProtobufCore

extension ProtoFileParser {
    static let scalarTypes: [String: FieldType] = [
        "double": .double, "float": .float, "int64": .int64, "uint64": .uint64, "int32": .int32, "fixed64": .fixed64,
        "fixed32": .fixed32, "bool": .bool, "string": .string, "bytes": .bytes, "uint32": .uint32,
        "sfixed32": .sfixed32,
        "sfixed64": .sfixed64, "sint32": .sint32, "sint64": .sint64
    ]

    /// `[label] type name = number [options];`, a `group`, or a `map<K, V>`: a field of message `index` (in `oneof`), or an
    /// extension of `extendee` declared in message `index` (or at file level).
    mutating func field(in index: Int?, oneof: Int32?, extendee: String?) throws(ProtoCompileError) {
        let start = stream.current
        var label: FieldLabel?
        if let word = ["optional": FieldLabel.optional, "required": .required, "repeated": .repeated][start.text],
            start.kind == .identifier, stream.peek().kind == .identifier || stream.peek().isSymbol(".")
        {
            stream.take()
            label = word
        }
        if oneof != nil, label != nil { throw stream.error("fields in oneofs must not have labels", at: start) }
        if stream.current.isIdentifier("map"), stream.peek().isSymbol("<") {
            guard label == nil, oneof == nil, extendee == nil, let index else {
                throw stream.error("map fields cannot have labels, be in a oneof or extend a message", at: start)
            }
            try mapField(in: index, start: start)
            return
        }
        let isGroup = stream.current.isIdentifier("group") && stream.peek().kind == .identifier
        if label == nil, oneof == nil, !isProto3, !isEditions {
            throw stream.error("expected \"required\", \"optional\", or \"repeated\"", at: start)
        }
        if isProto3 && label == .required || isEditions && label != nil && label != .repeated {
            throw stream.error("\(label == .required ? "required" : "optional") is not allowed here", at: start)
        }
        var descriptor = FieldDescriptor(label: label ?? .optional)
        descriptor.proto3Optional = isProto3 && label == .optional && extendee == nil
        descriptor.oneofIndex = oneof
        var named = false
        if isGroup {
            stream.take()
            guard !isProto3, !isEditions else {
                throw stream.error("groups are not supported in this syntax", at: start)
            }
            descriptor.type = .group
            named = true
        } else {
            let typeName = try stream.fullIdentifier("a field type")
            if let scalar = Self.scalarTypes[typeName] {
                descriptor.type = scalar
            } else {
                descriptor.type = .message
                descriptor.typeName = typeName
                named = true
            }
        }
        let nameToken = stream.current
        let name = try stream.identifier("a field name")
        try stream.expect("=")
        descriptor.number = try fieldNumber()
        if isGroup {
            guard name.first?.isUppercase == true else {
                throw stream.error("group names must start with a capital letter", at: nameToken)
            }
            descriptor.name = name.lowercased()
            descriptor.typeName = "." + fullName(name, in: index)
        } else {
            descriptor.name = name
        }
        descriptor.jsonName = ProtoParser.jsonName(for: descriptor.name)
        if let extendee { descriptor.extendee = extendee }
        var parsed = ParsedField(
            descriptor: descriptor, namedType: named, scope: extendee == nil ? nil : index,
            line: start.line, column: start.column)
        try fieldOptions(&parsed)
        if isGroup {
            try openGroup(parsed, name: name, in: index, start: start)
            return
        }
        try stream.expect(";")
        store(parsed, in: index, isExtension: extendee != nil)
    }

    private mutating func store(_ field: ParsedField, in index: Int?, isExtension: Bool) {
        if isExtension {
            file.extensions.append(field)
        } else if let index {
            file.messages[index].fields.append(field)
        }
    }

    /// `[default = …, json_name = "…", other = …]`: the first two are kept apart, as they are not options.
    private mutating func fieldOptions(_ field: inout ParsedField) throws(ProtoCompileError) {
        guard stream.accept("[") else { return }
        repeat {
            let token = stream.current
            let option = try optionAssignment()
            if option.name == [.field("default")] {
                guard field.defaultValue == nil else { throw stream.error("already set option \"default\"", at: token) }
                guard !isProto3 else {
                    throw stream.error("explicit default values are not allowed in proto3", at: token)
                }
                field.defaultValue = option.value
            } else if option.name == [.field("json_name")] {
                guard case .string(let bytes) = option.value else {
                    throw stream.error("expected a string for json_name", at: token)
                }
                guard field.descriptor.extendee.isEmpty else {
                    throw stream.error("option json_name is not allowed on extension fields", at: token)
                }
                field.descriptor.jsonName = String(decoding: bytes, as: UTF8.self)
            } else {
                field.options.append(option)
            }
        } while stream.accept(",")
        try stream.expect("]")
    }

    /// A group's message, nested where the group is declared, and its body as a message scope.
    private mutating func openGroup(_ field: ParsedField, name: String, in index: Int?, start: ProtoToken)
        throws(ProtoCompileError)
    {
        file.messages.append(
            ParsedMessage(
                descriptor: MessageDescriptor(name: name), parent: index, fullName: fullName(name, in: index),
                line: start.line, column: start.column))
        store(field, in: index, isExtension: !field.descriptor.extendee.isEmpty)
        try push(.message(file.messages.count - 1))
    }

    /// `map<K, V> name = number [options];`: a repeated field of a nested `NameEntry` message with `key` and `value`.
    private mutating func mapField(in index: Int, start: ProtoToken) throws(ProtoCompileError) {
        stream.take()
        try stream.expect("<")
        let keyToken = stream.current
        let keyName = try stream.fullIdentifier("a map key type")
        guard let key = Self.scalarTypes[keyName], key != .double, key != .float, key != .bytes else {
            throw stream.error("key in map fields cannot be float/double, bytes or message types", at: keyToken)
        }
        try stream.expect(",")
        let valueName = try stream.fullIdentifier("a map value type")
        try stream.expect(">")
        let name = try stream.identifier("a field name")
        try stream.expect("=")
        let number = try fieldNumber()
        let entryName = Self.mapEntryName(name)
        let entryFullName = fullName(entryName, in: index)
        var keyField = FieldDescriptor(name: "key", number: 1, label: .optional, type: key, jsonName: "key")
        keyField.jsonName = "key"
        var valueField = FieldDescriptor(name: "value", number: 2, label: .optional, jsonName: "value")
        if let scalar = Self.scalarTypes[valueName] {
            valueField.type = scalar
        } else {
            valueField.type = .message
            valueField.typeName = valueName
        }
        var entry = ParsedMessage(
            descriptor: MessageDescriptor(name: entryName), parent: index, fullName: entryFullName, line: start.line,
            column: start.column)
        entry.descriptor.options = [0x38, 0x01]  // map_entry = true
        entry.fields = [
            ParsedField(descriptor: keyField, namedType: false, line: start.line, column: start.column),
            ParsedField(
                descriptor: valueField, namedType: Self.scalarTypes[valueName] == nil, line: start.line,
                column: start.column)
        ]
        file.messages.append(entry)
        var field = ParsedField(
            descriptor: FieldDescriptor(
                name: name, number: number, label: .repeated, type: .message, typeName: "." + entryFullName,
                jsonName: ProtoParser.jsonName(for: name)),
            namedType: true, line: start.line, column: start.column)
        try fieldOptions(&field)
        try stream.expect(";")
        file.messages[index].fields.append(field)
    }

    /// A field number: 1 through 2^29-1.
    private mutating func fieldNumber() throws(ProtoCompileError) -> Int32 {
        let token = stream.current
        let number = try stream.integer("a field number")
        guard number >= 1, number <= Int64(FieldNumber.maximum) else {
            throw stream.error("field numbers must be positive integers up to \(FieldNumber.maximum)", at: token)
        }
        return Int32(number)
    }

    /// protoc's entry name for a map field: the name in CamelCase (underscores dropped, the next letter upper-cased), then `Entry`.
    static func mapEntryName(_ name: String) -> String {
        var result = ""
        var upper = true
        for character in name {
            if character == "_" {
                upper = true
            } else {
                result += upper ? character.uppercased() : String(character)
                upper = false
            }
        }
        return result + "Entry"
    }
}
