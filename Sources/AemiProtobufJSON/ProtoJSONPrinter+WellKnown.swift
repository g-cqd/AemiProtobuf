import AemiProtobufSchema

extension ProtoJSONPrinter {
    /// Writes the JSON form of a well-known type.
    mutating func expandWellKnown(
        _ kind: WellKnownType, _ message: DynamicMessage, _ type: DynamicMessageType
    ) throws(ProtoJSONError) {
        let fields = message.fields
        let path = type.name
        switch kind {
            case .timestamp, .duration:
                guard case .int64(let seconds) = fields[1] ?? .int64(0),
                    case .int32(let nanos) = fields[2] ?? .int32(0),
                    let text = kind == .timestamp
                        ? ProtoJSONTime.timestamp(seconds: seconds, nanos: nanos)
                        : ProtoJSONTime.duration(seconds: seconds, nanos: nanos)
                else { throw .invalid("out of range", path: path) }
                output.appendQuoted(text)
            case .fieldMask:
                guard case .list(let items) = fields[1] ?? .list([]) else { throw .invalid("no paths", path: path) }
                var paths: [String] = []
                for item in items {
                    guard case .string(let raw) = item, let camel = ProtoJSONPaths.camel(raw) else {
                        throw .invalid("a path with no lowerCamel form", path: path)
                    }
                    paths.append(camel)
                }
                output.appendQuoted(paths.joined(separator: ","))
            case .wrapper:
                guard let field = type.field(number: 1) else { throw .invalid("a wrapper without value", path: path) }
                let value = fields[1] ?? schema.defaultValue(of: field.descriptor, typeName: nil)
                stack.append(.value(value, field.type, typeName: nil))
            case .structure:
                guard let entry = type.field(number: 1)?.mapEntry, case .map(let map) = fields[1] ?? .map([:]) else {
                    throw .invalid("a Struct without fields", path: path)
                }
                stack.append(.map(map, entry))
            case .value: try expandValue(fields, path)
            case .listValue:
                let items = fields[1] ?? .list([])
                stack.append(.value(items, .message, typeName: WellKnownType.valueType))
            case .any: try expandAny(fields, path)
        }
    }

    private mutating func expandValue(_ fields: [Int32: DynamicValue], _ path: String) throws(ProtoJSONError) {
        if fields[1] != nil {
            output.append("null")
        } else if case .double(let number)? = fields[2] {
            guard let text = ProtoJSONOutput.number(number) else {
                throw .invalid("a Value number is not finite", path: path)
            }
            output.append(text)
        } else if case .string(let text)? = fields[3] {
            output.appendQuoted(text)
        } else if case .bool(let flag)? = fields[4] {
            output.append(flag ? "true" : "false")
        } else if let nested = fields[5] ?? fields[6] {
            stack.append(.value(nested, .message, typeName: nil))
        } else {
            throw .invalid("a Value with no kind set", path: path)
        }
    }

    /// An `Any` is `{}` when empty; otherwise its message is decoded from `value` by its type URL and written with `@type` first,
    /// its JSON form under `value` for a well-known type.
    private mutating func expandAny(_ fields: [Int32: DynamicValue], _ path: String) throws(ProtoJSONError) {
        guard case .string(let url) = fields[1] ?? .string("") else {
            throw .invalid("type_url is not a string", path: path)
        }
        guard case .bytes(let bytes) = fields[2] ?? .bytes([]) else { throw .invalid("value is not bytes", path: path) }
        if url.isEmpty && bytes.isEmpty {
            output.append("{}")
            return
        }
        guard let slash = url.lastIndex(of: "/") else { throw .invalid("\(url) is not a type URL", path: path) }
        let name = String(url[url.index(after: slash)...])
        guard let type = schema.messageType(named: name) else { throw .unknownType(name) }
        let inner: DynamicMessage
        do throws(DynamicMessageError) {
            inner = try schema.decode(bytes, as: name)
        } catch {
            throw .dynamic(error)
        }
        guard WellKnownType.hasJSONForm(name) else {
            try expandObject(inner, type, typeURL: url)
            return
        }
        output.open("{")
        output.key("@type")
        output.appendQuoted(url)
        output.key("value")
        stack.append(.text("}"))
        stack.append(.message(inner))
    }
}
