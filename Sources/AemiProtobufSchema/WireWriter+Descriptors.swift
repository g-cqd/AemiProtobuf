import AemiProtobufCore

/// The shapes `descriptor.proto` writes, in the presence it gives them: strings and numbers written when protoc sets them,
/// options as the raw messages protoc wrote.
extension WireWriter {
    mutating func appendField(_ number: FieldNumber, nonEmpty value: String) {
        guard !value.isEmpty else { return }
        appendField(number, value)
    }

    mutating func appendField(_ number: FieldNumber, _ value: String?) {
        guard let value else { return }
        appendTag(number, .lengthDelimited)
        appendString(value)
    }

    mutating func appendField(_ number: FieldNumber, raw value: [UInt8]?) {
        guard let value else { return }
        appendTag(number, .lengthDelimited)
        appendBytes(value)
    }

    mutating func appendField(_ number: FieldNumber, _ value: Int32?) {
        guard let value else { return }
        appendTag(number, .varint)
        appendInt32(value)
    }

    mutating func appendField(_ number: FieldNumber, _ value: Bool?) {
        guard let value else { return }
        appendTag(number, .varint)
        appendVarint(value ? 1 : 0)
    }

    mutating func appendMessages<D>(
        _ number: FieldNumber, _ items: [D], _ encode: (D, inout WireWriter) throws(WireError) -> Void
    ) throws(WireError) {
        for item in items {
            try appendMessage(field: number) { w throws(WireError) in try encode(item, &w) }
        }
    }
}
