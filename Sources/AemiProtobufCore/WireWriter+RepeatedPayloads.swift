extension WireWriter {
    /// Writes a `repeated string` field, one record per element, sized first and written through one buffer: per element, the
    /// tag, the length and the UTF-8 copied in one move (roadmap 0019). A Swift `String` is well-formed UTF-8, so nothing is
    /// validated.
    /// - Complexity: O(total bytes), two passes over the elements.
    public mutating func appendRepeatedStrings(field: FieldNumber, _ values: [String]) {
        unsafe appendRepeatedPayloads(field, values, count: \.utf8.count) { value, destination in
            var value = value
            value.withUTF8 { source in
                guard let base = source.baseAddress else { return }
                unsafe destination.copyMemory(from: UnsafeRawBufferPointer(start: base, count: source.count))
            }
        }
    }

    /// Writes a `repeated bytes` field, one record per element, as ``appendRepeatedStrings(field:_:)`` does.
    public mutating func appendRepeatedBytes(field: FieldNumber, _ values: [[UInt8]]) {
        unsafe appendRepeatedPayloads(field, values, count: \.count) { value, destination in
            value.withUnsafeBytes { source in unsafe destination.copyMemory(from: source) }
        }
    }

    private mutating func appendRepeatedPayloads<Element>(
        _ field: FieldNumber, _ values: [Element], count: (Element) -> Int,
        copy: (Element, UnsafeMutableRawBufferPointer) -> Void
    ) {
        guard !values.isEmpty else { return }
        let tag = UInt64(FieldTag(fieldNumber: field, wireType: .lengthDelimited).rawValue)
        let tagWidth = Self.varintWidth(tag)
        var size = 0
        for value in values {
            let length = count(value)
            size += tagWidth + Self.varintWidth(UInt64(length)) + length
        }
        let start = bytes.count
        bytes.append(contentsOf: repeatElement(0, count: size))
        // Every write stays below `start + size`, the total summed above.
        bytes.withUnsafeMutableBytes { buffer in
            var position = start
            func varint(_ value: UInt64) {
                var rest = value
                while rest >= 0x80 {
                    unsafe buffer[position] = UInt8(truncatingIfNeeded: rest) | 0x80
                    position += 1
                    rest >>= 7
                }
                unsafe buffer[position] = UInt8(truncatingIfNeeded: rest)
                position += 1
            }
            for value in values {
                let length = count(value)
                varint(tag)
                varint(UInt64(length))
                unsafe copy(value, UnsafeMutableRawBufferPointer(rebasing: buffer[position ..< position + length]))
                position += length
            }
        }
    }
}
