/// Base64 as the JSON mapping uses it for `bytes`: written in the standard alphabet with padding, read in either the standard or
/// the URL-safe alphabet, padded or not.
enum ProtoJSONBase64 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)

    static func encode(_ bytes: [UInt8]) -> String {
        var out: [UInt8] = []
        out.reserveCapacity((bytes.count + 2) / 3 * 4)
        var index = 0
        while index < bytes.count {
            let rest = bytes.count - index
            let b0 = UInt32(bytes[index])
            let b1 = rest > 1 ? UInt32(bytes[index + 1]) : 0
            let b2 = rest > 2 ? UInt32(bytes[index + 2]) : 0
            let word = b0 << 16 | b1 << 8 | b2
            out.append(alphabet[Int(word >> 18 & 63)])
            out.append(alphabet[Int(word >> 12 & 63)])
            out.append(rest > 1 ? alphabet[Int(word >> 6 & 63)] : UInt8(ascii: "="))
            out.append(rest > 2 ? alphabet[Int(word & 63)] : UInt8(ascii: "="))
            index += 3
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// - Returns: the bytes, or `nil` for a character outside both alphabets, misplaced padding, or a dangling sixth bit.
    static func decode(_ text: String) -> [UInt8]? {
        var values: [UInt8] = []
        var padding = 0
        for byte in text.utf8 {
            if byte == UInt8(ascii: "=") {
                padding += 1
                continue
            }
            guard padding == 0, let value = sextet(byte) else { return nil }
            values.append(value)
        }
        guard values.count % 4 != 1, padding == 0 || (values.count + padding) % 4 == 0, padding <= 2 else { return nil }
        var out: [UInt8] = []
        out.reserveCapacity(values.count * 3 / 4)
        var index = 0
        while index < values.count {
            let chunk = values[index ..< min(index + 4, values.count)]
            var word: UInt32 = 0
            for value in chunk { word = word << 6 | UInt32(value) }
            word <<= UInt32(6 * (4 - chunk.count))
            out.append(UInt8(word >> 16 & 0xFF))
            if chunk.count > 2 { out.append(UInt8(word >> 8 & 0xFF)) }
            if chunk.count > 3 { out.append(UInt8(word & 0xFF)) }
            index += 4
        }
        return out
    }

    private static func sextet(_ byte: UInt8) -> UInt8? {
        switch byte {
            case UInt8(ascii: "A") ... UInt8(ascii: "Z"): byte - UInt8(ascii: "A")
            case UInt8(ascii: "a") ... UInt8(ascii: "z"): byte - UInt8(ascii: "a") + 26
            case UInt8(ascii: "0") ... UInt8(ascii: "9"): byte - UInt8(ascii: "0") + 52
            case UInt8(ascii: "+"), UInt8(ascii: "-"): 62
            case UInt8(ascii: "/"), UInt8(ascii: "_"): 63
            default: nil
        }
    }
}
