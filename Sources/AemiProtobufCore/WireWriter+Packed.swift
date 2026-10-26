extension WireWriter {
    /// Writes a packed `repeated` field of 4- or 8-byte numbers (`Float`, `Double`, `Int32`, `UInt32`, `Int64`, `UInt64`) as one
    /// length-delimited record of little-endian words, in a single copy. Writes nothing for an empty array.
    /// - Precondition: `MemoryLayout<T>.size` is 4 or 8, which every type above satisfies.
    /// - Complexity: O(values.count), one append.
    public mutating func appendPackedLittleEndian<T: BitwiseCopyable>(field: FieldNumber, _ values: [T]) {
        precondition(MemoryLayout<T>.size == 4 || MemoryLayout<T>.size == 8, "packed words are 4 or 8 bytes")
        guard !values.isEmpty else { return }
        appendTag(field, .lengthDelimited)
        appendVarint(UInt64(values.count * MemoryLayout<T>.size))
        #if _endian(little)
            values.withUnsafeBytes { unsafe bytes.append(contentsOf: $0) }
        #else
            for value in values {
                withUnsafeBytes(of: value) { raw in for byte in unsafe raw.reversed() { bytes.append(byte) } }
            }
        #endif
    }
}
