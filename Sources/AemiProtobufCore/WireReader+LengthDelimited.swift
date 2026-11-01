import AemiKernel
import AemiKernels

// The length-delimited reads: bytes, strings and nested messages. Apart from WireReader.swift to keep
// each file within the 250 lines SourceStructureTests allows.
extension WireReader {
    // MARK: Length-delimited

    /// Reads a length prefix and claims the payload that follows it.
    /// - Returns: the payload's range in the buffer. `offset` is left after the payload.
    mutating func takePayload() throws(WireError) -> Range<Int> {
        let start = offset
        let declared = try readVarint()
        let available = end - offset
        guard declared <= UInt64(available) else {
            throw .lengthOutOfBounds(declared: declared, remaining: available, at: start)
        }
        let lower = offset
        offset += Int(declared)  // `declared <= available`, so it fits Int
        return lower ..< offset
    }

    /// Reads a `bytes` field.
    public mutating func readBytes() throws(WireError) -> [UInt8] {
        let range = try takePayload()
        return unsafe Array(UnsafeRawBufferPointer(rebasing: buffer[range]))
    }

    /// Reads a `string` field, validating UTF-8 (RFC 3629) before it makes the `String`.
    /// - Throws: ``WireError/invalidUTF8(at:)`` with the offset of the first byte of the string.
    public mutating func readString() throws(WireError) -> String {
        let range = try takePayload()
        guard !range.isEmpty else { return "" }
        let payload = unsafe UnsafeRawBufferPointer(rebasing: buffer[range])
        let bytes = unsafe payload.bindMemory(to: UInt8.self)
        guard let base = bytes.baseAddress,
            unsafe AemiKernels.firstInvalidUTF8(base: base, count: bytes.count) == bytes.count
        else { throw .invalidUTF8(at: range.lowerBound) }
        return unsafe String(decoding: bytes, as: UTF8.self)  // validated above, so nothing is repaired
    }

    /// Reads a nested message. `body` gets a reader limited to the message's bytes, one level deeper. The caller's reader
    /// continues after the message whether or not `body` read all of it.
    /// - Throws: ``WireError/depthExceeded(limit:at:)`` past `limits.maxDepth`, ``WireError/lengthOutOfBounds(declared:remaining:at:)``,
    ///   or whatever `body` throws.
    public mutating func readMessage<R>(
        _ body: (inout WireReader) throws(WireError) -> R
    ) throws(WireError) -> R {
        guard depth < limits.maxDepth else { throw .depthExceeded(limit: limits.maxDepth, at: offset) }
        let range = try takePayload()
        var nested = unsafe WireReader(
            buffer: buffer,
            offset: range.lowerBound,
            end: range.upperBound,
            depth: depth + 1,
            limits: limits
        )
        return try body(&nested)
    }
}
