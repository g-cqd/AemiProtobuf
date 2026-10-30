import AemiProtobufSchema

extension ProtoJSONPrinter {
    /// Writes one value: 64-bit integers as strings, non-finite floats as `"NaN"` / `"Infinity"` / `"-Infinity"`, bytes in
    /// base64, an enumeration by name (by number when it has none; `NullValue` as `null`). A list pushes its elements.
    mutating func write(_ value: DynamicValue, _ type: FieldType, _ typeName: String?) throws(ProtoJSONError) {
        switch value {
            case .message(let message): stack.append(.message(message))
            case .list(let items):
                output.open("[")
                stack.append(.text("]"))
                for item in items.reversed() {
                    stack.append(.value(item, type, typeName: typeName))
                    stack.append(.separator)
                }
            case .map: throw .invalid("a map where a value was expected", path: typeName ?? "")
            case .int32(let v): output.append(String(v))
            case .uint32(let v): output.append(String(v))
            case .int64(let v): output.append("\"" + String(v) + "\"")
            case .uint64(let v): output.append("\"" + String(v) + "\"")
            case .double(let v): output.append(ProtoJSONOutput.number(v) ?? "\"" + ProtoJSONOutput.special(v) + "\"")
            case .float(let v): output.append(ProtoJSONOutput.number(v) ?? "\"" + ProtoJSONOutput.special(v) + "\"")
            case .bool(let v): output.append(v ? "true" : "false")
            case .string(let v): output.appendQuoted(v)
            case .bytes(let v):
                guard type == .bytes else { throw .invalid("a string that is not UTF-8", path: typeName ?? "") }
                output.appendQuoted(ProtoJSONBase64.encode(v))
            case .enumeration(let number):
                if typeName == WellKnownType.nullValue {
                    output.append("null")
                } else if let name = typeName.flatMap(schema.enumeration(named:))?.values
                    .first(where: { $0.number == number })?
                    .name
                {
                    output.appendQuoted(name)
                } else {
                    output.append(String(number))
                }
        }
    }
}
