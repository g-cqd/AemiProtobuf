/// Decodes the base64 the generated sources embed (standard alphabet; white space and padding skipped), so this module needs no
/// Foundation.
enum EmbeddedBase64 {
    /// `descriptor.proto`'s files, decoded once.
    static let descriptorProto: [FileDescriptor] =
        (try? FileDescriptorSet.decode(from: decode(GeneratedDescriptorProto.base64)))?.files ?? []

    static func decode(_ text: String) -> [UInt8] {
        var out: [UInt8] = []
        var word: UInt32 = 0
        var count = 0
        for byte in text.utf8 {
            let value: UInt32
            switch byte {
                case UInt8(ascii: "A") ... UInt8(ascii: "Z"): value = UInt32(byte - 65)
                case UInt8(ascii: "a") ... UInt8(ascii: "z"): value = UInt32(byte - 97 + 26)
                case UInt8(ascii: "0") ... UInt8(ascii: "9"): value = UInt32(byte - 48 + 52)
                case UInt8(ascii: "+"): value = 62
                case UInt8(ascii: "/"): value = 63
                default: continue
            }
            word = word << 6 | value
            count += 1
            if count == 4 {
                out.append(UInt8(word >> 16 & 0xFF))
                out.append(UInt8(word >> 8 & 0xFF))
                out.append(UInt8(word & 0xFF))
                word = 0
                count = 0
            }
        }
        if count == 3 {
            out.append(UInt8(word >> 10 & 0xFF))
            out.append(UInt8(word >> 2 & 0xFF))
        } else if count == 2 {
            out.append(UInt8(word >> 4 & 0xFF))
        }
        return out
    }
}
