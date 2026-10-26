extension WireReader {
    /// Reads a packed `repeated` field of 4- or 8-byte numbers: the length prefix, then the little-endian words, in a single copy.
    /// - Precondition: `MemoryLayout<T>.size` is 4 or 8.
    /// - Throws: ``WireError/lengthOutOfBounds(declared:remaining:at:)`` for a length past the end, and
    ///   ``WireError/truncated(at:)`` at the payload's first byte if its length is not a multiple of the word size.
    /// - Complexity: O(element count), one allocation.
    public mutating func readPackedLittleEndian<T: BitwiseCopyable>(_ type: T.Type) throws(WireError) -> [T] {
        let width = MemoryLayout<T>.size
        precondition(width == 4 || width == 8, "packed words are 4 or 8 bytes")
        let range = try takePayload()
        guard range.count % width == 0 else { throw .truncated(at: range.lowerBound) }
        let count = range.count / width
        return unsafe [T](unsafeUninitializedCapacity: count) { out, initialized in
            #if _endian(little)
                unsafe UnsafeMutableRawBufferPointer(out)
                    .copyMemory(from: UnsafeRawBufferPointer(rebasing: buffer[range]))
            #else
                for index in 0 ..< count {
                    for byte in 0 ..< width {
                        unsafe UnsafeMutableRawBufferPointer(out)[index * width + byte] =
                            buffer[range.upperBound - 1 - index * width - byte]
                    }
                }
            #endif
            initialized = count
        }
    }
}
