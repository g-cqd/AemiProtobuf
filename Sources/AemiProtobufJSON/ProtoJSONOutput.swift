/// JSON text being written: escaping and number forms.
struct ProtoJSONOutput {
    var bytes: [UInt8] = []
    /// Whether the last thing written opened an object or array, so the next member or element takes no comma.
    var opened = false

    mutating func append(_ text: String) { bytes.append(contentsOf: text.utf8) }

    /// Writes `{` or `[`.
    mutating func open(_ bracket: String) {
        append(bracket)
        opened = true
    }

    /// Writes the comma before a member or element, unless it is the first.
    mutating func separate() {
        if !opened { bytes.append(UInt8(ascii: ",")) }
        opened = false
    }

    /// Writes a member's key: the comma before it, the quoted name and the colon.
    mutating func key(_ name: String) {
        separate()
        appendQuoted(name)
        bytes.append(UInt8(ascii: ":"))
    }

    /// Writes `text` as a JSON string: quotes, backslashes and control characters escaped, everything else as UTF-8.
    mutating func appendQuoted(_ text: String) {
        bytes.append(UInt8(ascii: "\""))
        // Most strings need no escape: copy them whole.
        if !text.utf8.contains(where: { $0 < 0x20 || $0 == UInt8(ascii: "\"") || $0 == UInt8(ascii: "\\") }) {
            bytes.append(contentsOf: text.utf8)
            bytes.append(UInt8(ascii: "\""))
            return
        }
        for byte in text.utf8 {
            switch byte {
                case UInt8(ascii: "\""): append("\\\"")
                case UInt8(ascii: "\\"): append("\\\\")
                case 0x0A: append("\\n")
                case 0x0D: append("\\r")
                case 0x09: append("\\t")
                case 0x08: append("\\b")
                case 0x0C: append("\\f")
                case 0 ..< 0x20:
                    let hex = Array("0123456789abcdef".utf8)
                    append("\\u00")
                    bytes.append(hex[Int(byte >> 4)])
                    bytes.append(hex[Int(byte & 15)])
                default: bytes.append(byte)
            }
        }
        bytes.append(UInt8(ascii: "\""))
    }

    /// The shortest text that reads back as `value`, without a trailing `.0`; `nil` for NaN and the infinities, which are
    /// written as strings.
    static func number<T: BinaryFloatingPoint & LosslessStringConvertible>(_ value: T) -> String? {
        guard value.isFinite else { return nil }
        let text = value.description
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    /// `"NaN"`, `"Infinity"` or `"-Infinity"` for a value that is not finite.
    static func special<T: BinaryFloatingPoint>(_ value: T) -> String {
        value.isNaN ? "NaN" : value < 0 ? "-Infinity" : "Infinity"
    }
}
