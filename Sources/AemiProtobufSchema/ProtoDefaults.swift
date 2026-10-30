/// The `default_value` strings protoc writes: integers in decimal, `true` / `false`, an enumeration's value name, a string's
/// text, bytes C-escaped, floats as `SimpleDtoa` / `SimpleFtoa` (`inf`, `-inf`, `nan`). A default that does not fit the field is
/// refused, as protoc refuses it.
enum ProtoDefaults {
    static func apply(_ files: inout [ParsedFile]) throws(ProtoCompileError) {
        var enums: [String: EnumDescriptor] = [:]
        for file in files { for enumeration in file.enums { enums[enumeration.fullName] = enumeration.descriptor } }
        for index in files.indices {
            let name = files[index].name
            for message in files[index].messages.indices {
                for field in files[index].messages[message].fields.indices {
                    try apply(&files[index].messages[message].fields[field], enums, file: name)
                }
            }
            for field in files[index].extensions.indices {
                try apply(&files[index].extensions[field], enums, file: name)
            }
        }
    }

    private static func apply(_ field: inout ParsedField, _ enums: [String: EnumDescriptor], file: String)
        throws(ProtoCompileError)
    {
        guard let written = field.defaultValue else { return }
        let descriptor = field.descriptor
        func fail(_ message: String) -> ProtoCompileError {
            ProtoCompileError(file: file, line: field.line, column: field.column, message: message)
        }
        guard descriptor.label != .repeated else { throw fail("Repeated fields can't have default values.") }
        guard descriptor.type != .message, descriptor.type != .group else {
            throw fail("Messages can't have default values.")
        }
        let enumeration = enums[String(descriptor.typeName.dropFirst())]
        let value: DynamicValue
        do throws(ProtoValueError) {
            value = try ProtoValueConverter.convert(written, to: descriptor.type, enumeration: enumeration)
        } catch {
            throw fail("\(error.message) for default value of \"\(descriptor.name)\".")
        }
        field.descriptor.defaultValue = text(value, enumeration)
    }

    private static func text(_ value: DynamicValue, _ enumeration: EnumDescriptor?) -> String {
        switch value {
            case .double(let v): CFloatFormat.simple(v)
            case .float(let v): CFloatFormat.simple(v)
            case .string(let v): v
            case .bytes(let v): cEscape(v)
            default: ProtoLiteral.text(value, enumeration: enumeration)
        }
    }

    /// protoc's `CEscape`: the usual backslash escapes, other bytes outside printable ASCII as three octal digits.
    static func cEscape(_ bytes: [UInt8]) -> String {
        var out = ""
        for byte in bytes {
            switch byte {
                case 0x0A: out += "\\n"
                case 0x0D: out += "\\r"
                case 0x09: out += "\\t"
                case 0x22: out += "\\\""
                case 0x27: out += "\\'"
                case 0x5C: out += "\\\\"
                case 0x20 ... 0x7E: out.append(Character(Unicode.Scalar(byte)))
                default:
                    let octal = String(byte, radix: 8)
                    out += "\\" + String(repeating: "0", count: 3 - octal.count) + octal
            }
        }
        return out
    }
}
