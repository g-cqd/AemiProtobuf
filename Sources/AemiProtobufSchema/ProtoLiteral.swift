/// Constants as `.proto` source and text format write them: numbers in decimal (floats in their shortest form, `inf`, `-inf`,
/// `nan`), strings quoted with C escapes, enumerations by name.
enum ProtoLiteral {
    static func text(_ value: DynamicValue, enumeration: EnumDescriptor?) -> String {
        switch value {
            case .double(let v): floating(v.isNaN, v.isInfinite, v < 0, v.description)
            case .float(let v): floating(v.isNaN, v.isInfinite, v < 0, v.description)
            case .string(let v): quoted(Array(v.utf8), keepUTF8: true)
            case .bytes(let v): quoted(v, keepUTF8: false)
            case .enumeration(let number): enumeration?.values.first { $0.number == number }?.name ?? String(number)
            default: value.keyText
        }
    }

    private static func floating(_ nan: Bool, _ infinite: Bool, _ negative: Bool, _ description: String) -> String {
        if nan { return "nan" }
        if infinite { return negative ? "-inf" : "inf" }
        return description
    }

    /// `"…"` with the C escapes; bytes of 0x80 and above kept as they are when `keepUTF8`, octal otherwise.
    static func quoted(_ bytes: [UInt8], keepUTF8: Bool) -> String {
        guard keepUTF8 else { return "\"" + ProtoDefaults.cEscape(bytes) + "\"" }
        var ascii: [UInt8] = []
        var out = "\""
        for byte in bytes {
            if byte >= 0x80 {
                ascii.append(byte)
                continue
            }
            if !ascii.isEmpty {
                out += String(decoding: ascii, as: UTF8.self)
                ascii = []
            }
            out += ProtoDefaults.cEscape([byte])
        }
        return out + String(decoding: ascii, as: UTF8.self) + "\""
    }
}
