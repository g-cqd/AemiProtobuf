@testable import AemiProtobufCore

/// Runs `body` over `bytes` with a fresh reader. Shortens every reader test to one line.
func read<R>(
    _ bytes: [UInt8], limits: WireLimits = .default, _ body: (inout WireReader) throws(WireError) -> R
) throws(WireError) -> R {
    try WireReader.withReader(over: bytes, limits: limits, body)
}

/// The next tag, or a `truncated` error at the current offset when the input has ended.
func tag(_ reader: inout WireReader) throws(WireError) -> FieldTag {
    guard let tag = try reader.nextTag() else { throw .truncated(at: reader.offset) }
    return tag
}

/// Builds a writer, runs `body` on it and returns the bytes.
func written(_ body: (inout WireWriter) throws(WireError) -> Void) throws(WireError) -> [UInt8] {
    var writer = WireWriter()
    try body(&writer)
    return writer.bytes
}

func hex(_ string: String) -> [UInt8] {
    var out: [UInt8] = []
    var high: UInt8?
    for scalar in string.utf8 where scalar != 0x20 {
        let nibble = scalar <= 0x39 ? scalar - 0x30 : scalar - 0x61 + 10
        if let h = high {
            out.append(h << 4 | nibble)
            high = nil
        } else {
            high = nibble
        }
    }
    return out
}
