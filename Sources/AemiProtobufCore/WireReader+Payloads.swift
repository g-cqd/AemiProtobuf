import AemiKernel
import AemiKernels

extension WireReader {
    /// Reads a length prefix and returns where the payload that follows it lies in the buffer, leaving the reader after the
    /// payload. For a caller that decodes the payload later, or more than once, without copying it.
    /// - Throws: ``WireError/truncated(at:)``, ``WireError/malformedVarint(at:)`` or ``WireError/lengthOutOfBounds(declared:remaining:at:)``.
    public mutating func readPayloadRange() throws(WireError) -> Range<Int> { try takePayload() }

    /// Validates `bytes[range]` as UTF-8 (RFC 3629) and makes the `String`, for a payload located by ``readPayloadRange()``.
    /// - Precondition: `range` lies within `bytes`.
    /// - Throws: ``WireError/invalidUTF8(at:)`` with `range.lowerBound`.
    public static func string(from bytes: [UInt8], in range: Range<Int>) throws(WireError) -> String {
        precondition(range.lowerBound >= 0 && range.upperBound <= bytes.count, "range is outside the buffer")
        guard !range.isEmpty else { return "" }
        let result: String? = bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return nil }
            let slice = unsafe base + range.lowerBound
            guard unsafe AemiKernels.firstInvalidUTF8(base: slice, count: range.count) == range.count else {
                return nil
            }
            return unsafe String(decoding: UnsafeBufferPointer(start: slice, count: range.count), as: UTF8.self)
        }
        guard let result else { throw .invalidUTF8(at: range.lowerBound) }
        return result
    }

    /// Reads a length-delimited payload that is not a message, such as a packed run: `body` gets a reader limited to the
    /// payload at the **same** nesting depth, because a packed run adds no level of nesting. The caller's reader continues after
    /// the payload.
    /// - Throws: ``WireError/lengthOutOfBounds(declared:remaining:at:)`` or whatever `body` throws.
    public mutating func readPayload<R>(_ body: (inout WireReader) throws(WireError) -> R) throws(WireError) -> R {
        let range = try takePayload()
        var scoped = unsafe WireReader(
            buffer: buffer, offset: range.lowerBound, end: range.upperBound, depth: depth, limits: limits)
        return try body(&scoped)
    }

    /// The number of varints left to read: the bytes with the continuation bit clear. An upper bound on a packed run's element
    /// count, exact for a well-formed one; for sizing the array that will hold it.
    /// - Complexity: O(remaining bytes).
    public var remainingVarintCount: Int {
        var count = 0
        var index = offset
        // Eight bytes at a time: a byte with the high bit clear ends a varint, so count them with one mask and a popcount.
        while end - index >= 8 {
            let word = unsafe buffer.loadLE64(index)  // 8 bytes remain
            count += (~word & 0x8080_8080_8080_8080).nonzeroBitCount
            index += 8
        }
        while index < end {
            if unsafe buffer[index] < 0x80 { count += 1 }  // `index < end <= buffer.count`
            index += 1
        }
        return count
    }
}
