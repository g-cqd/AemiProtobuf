import AemiProtobufSchema

/// Reads one scalar field value from JSON as the mapping says: integers from numbers or strings (64-bit ones exactly), floats
/// also from `"NaN"`, `"Infinity"` and `"-Infinity"`, `bytes` from base64, enumerations from a name or a number.
struct ProtoJSONScalars {
    let schema: DynamicSchema
    let ignoreUnknownFields: Bool

    /// The value, or `nil` for an enumeration name the type lacks when unknown names are ignored.
    func value(_ shape: JSONShape, _ type: FieldType, typeName: String?, path: String) throws(ProtoJSONError)
        -> DynamicValue?
    {
        switch type {
            case .int32, .sint32, .sfixed32: return .int32(try integer(shape, Int32.self, path))
            case .int64, .sint64, .sfixed64: return .int64(try integer(shape, Int64.self, path))
            case .uint32, .fixed32: return .uint32(try integer(shape, UInt32.self, path))
            case .uint64, .fixed64: return .uint64(try integer(shape, UInt64.self, path))
            case .double:
                guard let value = floating(shape, ProtoJSONNumber.double) else {
                    throw .invalid("not a double", path: path)
                }
                return .double(value)
            case .float:
                guard let value = floating(shape, ProtoJSONNumber.float) else {
                    throw .invalid("not a float", path: path)
                }
                return .float(value)
            case .bool:
                guard case .bool(let value) = shape else { throw .invalid("not true or false", path: path) }
                return .bool(value)
            case .string:
                guard case .string(let value) = shape else { throw .invalid("not a string", path: path) }
                return .string(value)
            case .bytes:
                guard case .string(let text) = shape, let value = ProtoJSONBase64.decode(text) else {
                    throw .invalid("not base64", path: path)
                }
                return .bytes(value)
            case .enum: return try enumeration(shape, typeName: typeName, path: path)
            case .message, .group: throw .invalid("a message where a scalar was expected", path: path)
        }
    }

    /// A map key from its JSON object key: integers and `true` / `false` are written as strings.
    func key(_ text: String, _ type: FieldType, path: String) throws(ProtoJSONError) -> DynamicValue {
        if type == .bool {
            switch text {
                case "true": return .bool(true)
                case "false": return .bool(false)
                default: throw .invalid("map key \(text) is not true or false", path: path)
            }
        }
        guard let value = try value(.string(text), type, typeName: nil, path: path) else {
            throw .invalid("map key \(text)", path: path)
        }
        return value
    }

    private func enumeration(_ shape: JSONShape, typeName: String?, path: String) throws(ProtoJSONError)
        -> DynamicValue?
    {
        if case .string(let name) = shape {
            if let number = typeName.flatMap(schema.enumeration(named:))?.values.first(where: { $0.name == name })?
                .number
            {
                return .enumeration(number)
            }
            if ignoreUnknownFields { return nil }
            throw .invalid("\(name) names no value of \(typeName ?? "the enumeration")", path: path)
        }
        return .enumeration(try integer(shape, Int32.self, path))
    }

    private func floating<T>(_ shape: JSONShape, _ parse: (String, Bool) -> T?) -> T? {
        switch shape {
            case .number(let text): parse(text, false)
            case .string(let text): parse(text, true)
            default: nil
        }
    }

    /// An integer of type `T` from a number or a numeric string, exactly; refused when fractional or out of `T`'s range.
    private func integer<T: FixedWidthInteger>(_ shape: JSONShape, _: T.Type, _ path: String) throws(ProtoJSONError)
        -> T
    {
        let text: String
        switch shape {
            case .number(let value), .string(let value): text = value
            default: throw .invalid("not an integer", path: path)
        }
        guard let (negative, magnitude) = ProtoJSONNumber.integer(text) else {
            throw .invalid("\(text) is not an integer", path: path)
        }
        if !negative || magnitude == 0 {
            guard magnitude <= UInt64(T.max) else { throw .invalid("\(text) is out of range", path: path) }
            return T(magnitude)
        }
        guard T.isSigned, magnitude - 1 <= UInt64(T.max) else { throw .invalid("\(text) is out of range", path: path) }
        return T(truncatingIfNeeded: 0 &- magnitude)
    }
}
