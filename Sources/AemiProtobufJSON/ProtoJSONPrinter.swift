import AemiProtobufSchema

/// One JSON write, without recursion: a stack of what is still to be written. A message pushes its closing brace and its
/// members, last first, so they come off in order; a nested message is expanded when it comes off. Commas are the output's
/// business: none after an opening bracket, one before every other member or element.
struct ProtoJSONPrinter {
    enum Work {
        case text(String)
        /// A member's key, with the comma before it.
        case key(String)
        /// The comma before an array element.
        case separator
        case message(DynamicMessage)
        case value(DynamicValue, FieldType, typeName: String?)
        case map([DynamicValue: DynamicValue], DynamicField.MapEntry)
    }

    let schema: DynamicSchema
    let options: ProtoJSONCoder.Options
    var output = ProtoJSONOutput()
    var stack: [Work] = []

    init(schema: DynamicSchema, options: ProtoJSONCoder.Options) {
        self.schema = schema
        self.options = options
    }

    mutating func run(_ message: DynamicMessage) throws(ProtoJSONError) -> [UInt8] {
        stack = [.message(message)]
        while let work = stack.popLast() {
            switch work {
                case .text(let text):
                    // Only closing brackets are pushed as text: what follows them is never first.
                    output.append(text)
                    output.opened = false
                case .key(let name): output.key(name)
                case .separator: output.separate()
                case .message(let message): try expand(message)
                case .value(let value, let type, let typeName): try write(value, type, typeName)
                case .map(let map, let entry): writeMap(map, entry)
            }
        }
        return output.bytes
    }

    private mutating func expand(_ message: DynamicMessage) throws(ProtoJSONError) {
        guard let type = schema.messageType(named: message.typeName) else { throw .unknownType(message.typeName) }
        if let known = WellKnownType(type.name) {
            try expandWellKnown(known, message, type)
        } else {
            try expandObject(message, type, typeURL: nil)
        }
    }

    /// Writes `{`, then pushes `}` and the members, last first. An `Any`'s message leads with its `@type`.
    mutating func expandObject(_ message: DynamicMessage, _ type: DynamicMessageType, typeURL: String?)
        throws(ProtoJSONError)
    {
        output.open("{")
        if let typeURL {
            output.key("@type")
            output.appendQuoted(typeURL)
        }
        stack.append(.text("}"))
        for field in type.fields.reversed() {
            guard let work = try member(field, message.fields[field.number], type.name) else { continue }
            stack.append(work)
            stack.append(.key(options.useProtoFieldNames && !field.isExtension ? field.name : field.jsonName))
        }
    }

    /// What to write for a field, or `nil` to leave it out: an unset field, an implicit-presence field at its default, an empty
    /// repeated field or map. With `emitDefaultValues`, fields without presence are written at their defaults.
    private func member(_ field: DynamicField, _ value: DynamicValue?, _ message: String) throws(ProtoJSONError)
        -> Work?
    {
        let emit = options.emitDefaultValues
        guard let value else {
            guard emit, !field.hasPresence || field.isRepeated else { return nil }
            if let entry = field.mapEntry { return .map([:], entry) }
            if field.isRepeated { return .value(.list([]), field.type, typeName: field.typeName) }
            return .value(
                schema.defaultValue(of: field.descriptor, typeName: field.typeName), field.type,
                typeName: field.typeName)
        }
        if let entry = field.mapEntry {
            guard case .map(let map) = value else {
                throw .invalid("a map field holds no map", path: message + "." + field.name)
            }
            return map.isEmpty && !emit ? nil : .map(map, entry)
        }
        if case .list(let items) = value, items.isEmpty, !emit { return nil }
        if !field.isRepeated, !field.hasPresence, value.isImplicitDefault, !emit { return nil }
        return .value(value, field.type, typeName: field.typeName)
    }

    private mutating func writeMap(_ map: [DynamicValue: DynamicValue], _ entry: DynamicField.MapEntry) {
        output.open("{")
        stack.append(.text("}"))
        for (key, value) in map.sorted(by: { DynamicValue.keyPrecedes($0.key, $1.key) }).reversed() {
            stack.append(.value(value, entry.value.type, typeName: entry.valueTypeName))
            stack.append(.key(Self.keyText(key)))
        }
    }

    private static func keyText(_ key: DynamicValue) -> String {
        switch key {
            case .int32(let v): String(v)
            case .int64(let v): String(v)
            case .uint32(let v): String(v)
            case .uint64(let v): String(v)
            case .bool(let v): v ? "true" : "false"
            case .string(let v): v
            default: ""
        }
    }
}
