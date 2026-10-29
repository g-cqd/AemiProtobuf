import AemiProtobufSchema

/// A `[default = …]` as a Swift literal, from the text protoc stores (`FieldDescriptorProto.default_value`).
enum DefaultLiteral {
    /// Nil for a type with no default (a message).
    static func swift(_ text: String, for field: FieldDescriptor, symbols: SymbolTable) throws(GeneratorError)
        -> String?
    {
        switch field.type {
            case .message, .group: return nil
            case .bool: return text
            case .float, .double:
                switch text {
                    case "inf": return ".infinity"
                    case "-inf": return "-.infinity"
                    case "nan": return ".nan"
                    default: return text
                }
            case .string: return stringLiteral(text)
            case .bytes: return "[" + unescape(text).map(String.init).joined(separator: ", ") + "]"
            case .enum:
                guard case .enumeration(let enumeration)? = symbols[field.typeName]?.declaration else {
                    throw .unknownType(field.typeName)
                }
                return "." + SwiftNaming.enumCase(text, enumName: enumeration.name)
            default: return text
        }
    }

    /// A Swift string literal holding `text` exactly: protoc stores a string default unescaped.
    private static func stringLiteral(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
                case "\"": result += "\\\""
                case "\\": result += "\\\\"
                case "\n": result += "\\n"
                case "\r": result += "\\r"
                case "\t": result += "\\t"
                default:
                    if scalar.value < 0x20 || scalar.value == 0x7F {
                        result += "\\u{" + String(scalar.value, radix: 16) + "}"
                    } else {
                        result.unicodeScalars.append(scalar)
                    }
            }
        }
        return result + "\""
    }

    /// The bytes of a C-escaped `bytes` default (`\001\377`, `\x12`, `\n`, `\\`), as protoc stores it.
    static func unescape(_ text: String) -> [UInt8] {
        let bytes = Array(text.utf8)
        var result: [UInt8] = []
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            guard byte == UInt8(ascii: "\\"), index < bytes.count else {
                result.append(byte)
                continue
            }
            let next = bytes[index]
            index += 1
            switch next {
                case UInt8(ascii: "n"): result.append(0x0A)
                case UInt8(ascii: "r"): result.append(0x0D)
                case UInt8(ascii: "t"): result.append(0x09)
                case UInt8(ascii: "a"): result.append(0x07)
                case UInt8(ascii: "b"): result.append(0x08)
                case UInt8(ascii: "f"): result.append(0x0C)
                case UInt8(ascii: "v"): result.append(0x0B)
                case UInt8(ascii: "x"):
                    var value: UInt8 = 0
                    var digits = 0
                    while digits < 2, index < bytes.count, let digit = hex(bytes[index]) {
                        value = value &* 16 &+ digit
                        index += 1
                        digits += 1
                    }
                    result.append(value)
                case UInt8(ascii: "0") ... UInt8(ascii: "7"):
                    var value = UInt32(next - UInt8(ascii: "0"))
                    var digits = 1
                    while digits < 3, index < bytes.count,
                        (UInt8(ascii: "0") ... UInt8(ascii: "7")).contains(bytes[index])
                    {
                        value = value * 8 + UInt32(bytes[index] - UInt8(ascii: "0"))
                        index += 1
                        digits += 1
                    }
                    result.append(UInt8(truncatingIfNeeded: value))
                default: result.append(next)
            }
        }
        return result
    }

    private static func hex(_ byte: UInt8) -> UInt8? {
        switch byte {
            case UInt8(ascii: "0") ... UInt8(ascii: "9"): byte - UInt8(ascii: "0")
            case UInt8(ascii: "a") ... UInt8(ascii: "f"): byte - UInt8(ascii: "a") + 10
            case UInt8(ascii: "A") ... UInt8(ascii: "F"): byte - UInt8(ascii: "A") + 10
            default: nil
        }
    }
}
