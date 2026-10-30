/// Turns a constant as written into a field's value, as protoc checks options and defaults, and as text format reads scalars
/// (which also accepts `t` / `f`, `True` / `False`, numbers for enumerations, and `inf` / `nan` in any case).
enum ProtoValueConverter {
    /// - Throws: the reason, as protoc words it, when the constant does not fit the type.
    static func convert(
        _ value: ProtoOptionValue, to type: FieldType, enumeration: EnumDescriptor?, textFormat: Bool = false
    ) throws(ProtoValueError) -> DynamicValue {
        switch type {
            case .int32, .sint32, .sfixed32:
                return .int32(Int32(try signed(value, min: Int64(Int32.min), max: Int64(Int32.max))))
            case .int64, .sint64, .sfixed64: return .int64(try signed(value, min: .min, max: .max))
            case .uint32, .fixed32: return .uint32(UInt32(try unsigned(value, max: UInt64(UInt32.max))))
            case .uint64, .fixed64: return .uint64(try unsigned(value, max: .max))
            case .double: return .double(try floating(value, textFormat: textFormat))
            case .float:
                let wide = try floating(value, textFormat: textFormat)
                if case .float(let text, let negative) = value, let narrow = Float(Self.trimSuffix(text)) {
                    return .float(negative ? -narrow : narrow)
                }
                return .float(Float(wide))
            case .bool:
                switch value {
                    case .identifier("true", false): return .bool(true)
                    case .identifier("false", false): return .bool(false)
                    case .identifier("True", false) where textFormat, .identifier("t", false) where textFormat:
                        return .bool(true)
                    case .identifier("False", false) where textFormat, .identifier("f", false) where textFormat:
                        return .bool(false)
                    case .integer("1", false) where textFormat: return .bool(true)
                    case .integer("0", false) where textFormat: return .bool(false)
                    default: throw ProtoValueError("Value must be \"true\" or \"false\" for boolean option")
                }
            case .string:
                guard case .string(let bytes) = value else {
                    throw ProtoValueError("Value must be quoted string for string option")
                }
                guard let text = String(validating: bytes, as: UTF8.self) else {
                    throw ProtoValueError("String is not UTF-8")
                }
                return .string(text)
            case .bytes:
                guard case .string(let bytes) = value else {
                    throw ProtoValueError("Value must be quoted string for bytes option")
                }
                return .bytes(bytes)
            case .enum:
                if case .identifier(let name, false) = value {
                    guard let number = enumeration?.values.first(where: { $0.name == name })?.number else {
                        throw ProtoValueError("Enum type has no value named \"\(name)\"")
                    }
                    return .enumeration(number)
                }
                guard textFormat else { throw ProtoValueError("Value must be identifier for enum-valued option") }
                return .enumeration(Int32(try signed(value, min: Int64(Int32.min), max: Int64(Int32.max))))
            case .message, .group: throw ProtoValueError("a message literal is expected")
        }
    }

    private static func signed(_ value: ProtoOptionValue, min: Int64, max: Int64) throws(ProtoValueError) -> Int64 {
        guard case .integer(let text, let negative) = value, let magnitude = ProtoTokenStream.magnitude(text) else {
            throw ProtoValueError("Value must be integer")
        }
        if negative {
            guard magnitude <= UInt64(-(min + 1)) + 1 else { throw ProtoValueError("Value out of range") }
            return magnitude == 0 ? 0 : -Int64(magnitude - 1) - 1
        }
        guard magnitude <= UInt64(max) else { throw ProtoValueError("Value out of range") }
        return Int64(magnitude)
    }

    private static func unsigned(_ value: ProtoOptionValue, max: UInt64) throws(ProtoValueError) -> UInt64 {
        guard case .integer(let text, let negative) = value, let magnitude = ProtoTokenStream.magnitude(text) else {
            throw ProtoValueError("Value must be integer")
        }
        guard !negative || magnitude == 0 else { throw ProtoValueError("Value must be non-negative integer") }
        guard magnitude <= max else { throw ProtoValueError("Value out of range") }
        return magnitude
    }

    private static func floating(_ value: ProtoOptionValue, textFormat: Bool) throws(ProtoValueError) -> Double {
        switch value {
            case .integer(let text, let negative):
                guard let magnitude = ProtoTokenStream.magnitude(text) else {
                    throw ProtoValueError("Value must be number")
                }
                return negative ? -Double(magnitude) : Double(magnitude)
            case .float(let text, let negative):
                guard let parsed = Double(trimSuffix(text)) else { throw ProtoValueError("Value must be number") }
                return negative ? -parsed : parsed
            case .identifier(let name, let negative):
                let lower = name.lowercased()
                let infinite = textFormat ? lower == "inf" || lower == "infinity" : name == "inf"
                let notANumber = textFormat ? lower == "nan" : name == "nan"
                if infinite { return negative ? -.infinity : .infinity }
                if notANumber { return negative ? -.nan : .nan }
                throw ProtoValueError("Value must be number")
            default: throw ProtoValueError("Value must be number")
        }
    }

    static func trimSuffix(_ text: String) -> String {
        text.hasSuffix("f") || text.hasSuffix("F") ? String(text.dropLast()) : text
    }
}
