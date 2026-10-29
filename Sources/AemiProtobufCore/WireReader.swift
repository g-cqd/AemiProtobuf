import AemiKernel
import AemiKernels

/// A bounds-checked cursor over protobuf wire bytes. It reads one field at a time and never builds an intermediate
/// structure. Every read either returns a value or throws a ``WireError`` that carries the offset; no input traps, reads
/// past the buffer, or loops without consuming bytes.
///
/// The reader borrows its bytes. It is valid only inside the closure of a `withReader` call, which is how the caller's
/// buffer is guaranteed to outlive it. A nested message gets a sub-reader limited to its own bytes (``readMessage(_:)``).
///
/// - Note: `@safe` because the raw buffer is private and every access is checked against `end`, which `init` bounds by
///   the buffer's count.
@safe
public struct WireReader {
    let buffer: UnsafeRawBufferPointer
    /// Offset of the next unread byte. Always `<= end`.
    public private(set) var offset: Int
    /// Exclusive end of the bytes this reader may read. Always `<= buffer.count`.
    let end: Int
    let depth: Int
    let limits: WireLimits
    /// Offset of the tag read last, for errors raised by ``skipField(_:)``.
    var tagOffset: Int
    var groupScratch: [FieldNumber] = []

    init(buffer: UnsafeRawBufferPointer, offset: Int, end: Int, depth: Int, limits: WireLimits) {
        unsafe self.buffer = buffer
        self.offset = offset
        self.end = end
        self.depth = depth
        self.limits = limits
        self.tagOffset = offset
    }

    /// Whether every byte has been read.
    @inlinable public var isAtEnd: Bool { remaining == 0 }

    /// The number of unread bytes.
    public var remaining: Int { end - offset }

    // MARK: Entry points

    /// Runs `body` with a reader over `bytes`.
    /// - Throws: ``WireError/messageTooLarge(limit:)`` if `bytes` is longer than `limits.maxMessageBytes`, or whatever
    ///   `body` throws.
    public static func withReader<R>(
        over bytes: [UInt8], limits: WireLimits = .default, _ body: (inout WireReader) throws(WireError) -> R
    ) throws(WireError) -> R {
        // `Array.withUnsafeBytes` rethrows `any Error`, so the typed error travels out inside a `Result`.
        let result: Result<R, WireError> = bytes.withUnsafeBytes { raw in
            do throws(WireError) {
                return .success(try unsafe run(over: raw, limits: limits, body))
            } catch {
                return .failure(error)
            }
        }
        return try result.get()
    }

    /// Runs `body` with a reader over `span`. Same contract as ``withReader(over:limits:_:)-(Array<UInt8>,_,_)``.
    public static func withReader<R>(
        over span: RawSpan, limits: WireLimits = .default, _ body: (inout WireReader) throws(WireError) -> R
    ) throws(WireError) -> R {
        try span.withUnsafeBytes { (raw) throws(WireError) -> R in
            try unsafe run(over: raw, limits: limits, body)
        }
    }

    /// Runs `body` with a reader over `raw`, for callers that already hold a pointer (`Data`, a network buffer).
    /// - Precondition: `raw` stays valid and unmodified until `body` returns.
    @unsafe public static func withReader<R>(
        overUnsafeBytes raw: UnsafeRawBufferPointer, limits: WireLimits = .default,
        _ body: (inout WireReader) throws(WireError) -> R
    ) throws(WireError) -> R {
        try unsafe run(over: raw, limits: limits, body)
    }

    /// Runs `body` with a reader over `bytes[range]`, `depth` messages deep. Offsets, and the offsets in errors, count from
    /// the start of `bytes`, so an error in a nested message points into the original buffer.
    /// - Precondition: `range` lies within `bytes`. A range from this reader's own ``readPayloadRange()`` always does.
    /// - Throws: ``WireError/depthExceeded(limit:at:)`` if `depth` exceeds `limits.maxDepth`,
    ///   ``WireError/messageTooLarge(limit:)`` if the range is longer than `limits.maxMessageBytes`, or whatever `body` throws.
    public static func withReader<R>(
        over bytes: [UInt8], in range: Range<Int>, depth: Int, limits: WireLimits = .default,
        _ body: (inout WireReader) throws(WireError) -> R
    ) throws(WireError) -> R {
        precondition(range.lowerBound >= 0 && range.upperBound <= bytes.count, "range is outside the buffer")
        guard depth <= limits.maxDepth else { throw .depthExceeded(limit: limits.maxDepth, at: range.lowerBound) }
        let result: Result<R, WireError> = bytes.withUnsafeBytes { raw in
            do throws(WireError) {
                return .success(try unsafe run(over: raw, range: range, depth: depth, limits: limits, body))
            } catch {
                return .failure(error)
            }
        }
        return try result.get()
    }

    private static func run<R>(
        over raw: UnsafeRawBufferPointer, range: Range<Int>? = nil, depth: Int = 0, limits: WireLimits,
        _ body: (inout WireReader) throws(WireError) -> R
    ) throws(WireError) -> R {
        let span = range ?? 0 ..< raw.count
        guard span.count <= limits.maxMessageBytes else { throw .messageTooLarge(limit: limits.maxMessageBytes) }
        var reader = unsafe WireReader(
            buffer: raw, offset: span.lowerBound, end: span.upperBound, depth: depth, limits: limits)
        return try body(&reader)
    }

    // MARK: Fields

    /// Reads the next tag.
    /// - Returns: `nil` when the input is exhausted. An end-group tag is returned like any other.
    /// - Throws: ``WireError/truncated(at:)``, ``WireError/malformedVarint(at:)``, ``WireError/invalidTag(_:at:)`` or
    ///   ``WireError/invalidWireType(_:at:)``.
    ///   A tag is a 32-bit value, read in at most five bytes as C++ reads it: a longer encoding is `invalidTag`, even of a small
    ///   number.
    public mutating func nextTag() throws(WireError) -> FieldTag? {
        guard offset < end else { return nil }
        tagOffset = offset
        let raw = try readVarint()
        guard offset - tagOffset <= 5 else { throw .invalidTag(raw, at: tagOffset) }
        return try FieldTag(rawValue: raw, at: tagOffset)
    }

    /// Reads a varint. Accepts a non-minimal encoding of up to ten bytes; refuses an eleventh byte and a tenth byte above 1.
    /// - Throws: ``WireError/truncated(at:)`` or ``WireError/malformedVarint(at:)``, both at the varint's first byte.
    @inline(__always) public mutating func readVarint() throws(WireError) -> UInt64 {
        guard offset < end else { throw .truncated(at: offset) }
        // `offset < end <= buffer.count`, so the load is in bounds.
        let first = unsafe buffer[offset]
        if first < 0x80 {
            offset += 1
            return UInt64(first)
        }
        return try readLongVarint(first: first)
    }

    private mutating func readLongVarint(first: UInt8) throws(WireError) -> UInt64 {
        let start = offset
        var result = UInt64(first & 0x7F)
        var shift: UInt64 = 7
        var index = start + 1
        while index < end {
            let byte = unsafe buffer[index]  // `index < end`
            index += 1
            if shift == 63 {
                // The tenth byte may add only bit 63. A larger value overflows 64 bits; a set continuation bit asks for an
                // eleventh byte. protoc truncates the first and refuses the second (ADR-0003).
                guard byte <= 1 else { throw .malformedVarint(at: start) }
                offset = index
                return result | UInt64(byte) << 63
            }
            result |= UInt64(byte & 0x7F) << shift
            if byte < 0x80 {
                offset = index
                return result
            }
            shift += 7
        }
        throw .truncated(at: start)
    }

    /// Reads an `int32`: the low 32 bits of a varint, as the reference implementations do.
    @inlinable public mutating func readInt32() throws(WireError) -> Int32 {
        Int32(truncatingIfNeeded: try readVarint())
    }

    /// Reads four little-endian bytes.
    public mutating func readFixed32() throws(WireError) -> UInt32 {
        guard end - offset >= 4 else { throw .truncated(at: offset) }
        let value = unsafe buffer.loadLE32(offset)  // 4 bytes remain
        offset += 4
        return value
    }

    /// Reads eight little-endian bytes.
    public mutating func readFixed64() throws(WireError) -> UInt64 {
        guard end - offset >= 8 else { throw .truncated(at: offset) }
        let value = unsafe buffer.loadLE64(offset)  // 8 bytes remain
        offset += 8
        return value
    }

    /// Reads a `double`.
    @inlinable public mutating func readDouble() throws(WireError) -> Double {
        Double(bitPattern: try readFixed64())
    }

    /// Reads a `float`.
    @inlinable public mutating func readFloat() throws(WireError) -> Float {
        Float(bitPattern: try readFixed32())
    }

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
            buffer: buffer, offset: range.lowerBound, end: range.upperBound, depth: depth + 1, limits: limits)
        return try body(&nested)
    }
}
