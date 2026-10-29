import AemiKernel

/// Appends protobuf wire data to an owned byte array.
///
/// Appends never fail: a value's size is bounded by its type. Only ``appendMessage(field:_:)`` can throw, because it
/// enforces ``WireLimits``; when it throws, the writer is exactly as it was before the call.
public struct WireWriter {
    /// The bytes written so far.
    public internal(set) var bytes: [UInt8]
    private let limits: WireLimits
    private var depth = 0

    /// - Parameters:
    ///   - limits: nesting and message-size bounds for ``appendMessage(field:_:)``.
    ///   - capacity: bytes to reserve up front.
    public init(limits: WireLimits = .default, reservingCapacity capacity: Int = 0) {
        self.limits = limits
        bytes = []
        bytes.reserveCapacity(capacity)
    }

    /// Makes room for `additional` more bytes without a reallocation per call: nothing when there is room, else at least double.
    /// For a caller that knows the size of what it is about to write, such as a packed array.
    public mutating func reserve(additional: Int) {
        let needed = bytes.count + additional
        guard needed > bytes.capacity else { return }
        bytes.reserveCapacity(max(needed, bytes.capacity * 2))
    }

    /// Writes a field tag.
    public mutating func appendTag(_ field: FieldNumber, _ type: WireType) {
        appendVarint(UInt64(FieldTag(fieldNumber: field, wireType: type).rawValue))
    }

    /// Writes a varint (`uint64`, `uint32`, `bool`, enum).
    public mutating func appendVarint(_ value: UInt64) {
        // Most tags and lengths take one byte; skip the cross-module kernel call for them.
        guard value >= 0x80 else {
            bytes.append(UInt8(truncatingIfNeeded: value))
            return
        }
        Varint.append(value, to: &bytes)
    }

    /// Writes an `int32`, sign-extended to 64 bits so a negative value takes ten bytes, as the encoding requires.
    public mutating func appendInt32(_ value: Int32) {
        appendVarint(UInt64(bitPattern: Int64(value)))
    }

    /// Writes four little-endian bytes.
    public mutating func appendFixed32(_ value: UInt32) {
        withUnsafeBytes(of: value.littleEndian) { unsafe bytes.append(contentsOf: $0) }
    }

    /// Writes eight little-endian bytes.
    public mutating func appendFixed64(_ value: UInt64) {
        withUnsafeBytes(of: value.littleEndian) { unsafe bytes.append(contentsOf: $0) }
    }

    /// Writes a `double` as fixed64.
    @inlinable public mutating func appendDouble(_ value: Double) { appendFixed64(value.bitPattern) }

    /// Writes a `float` as fixed32.
    @inlinable public mutating func appendFloat(_ value: Float) { appendFixed32(value.bitPattern) }

    /// Writes a length-prefixed `string`. A Swift `String` is always well-formed UTF-8, so nothing is validated here.
    public mutating func appendString(_ value: String) {
        appendVarint(UInt64(value.utf8.count))  // O(1) for a native string
        bytes.append(contentsOf: value.utf8)
    }

    /// Writes a length-prefixed `bytes` field.
    public mutating func appendBytes(_ value: [UInt8]) {
        appendVarint(UInt64(value.count))
        bytes.append(contentsOf: value)
    }

    /// Appends already-encoded bytes with no prefix: the body of a nested message, or a pre-serialized field.
    public mutating func appendRaw(_ value: [UInt8]) { bytes.append(contentsOf: value) }

    /// Writes a nested message: the tag, a minimal length prefix, then what `body` appends.
    ///
    /// The body is written in place after a one-byte length slot. A body of 128 bytes or more shifts once to widen the
    /// slot, so a small message costs no scratch buffer and a large one a single move.
    ///
    /// - Throws: ``WireError/depthExceeded(limit:at:)`` past `limits.maxDepth`, ``WireError/messageTooLarge(limit:)`` if
    ///   the body exceeds `limits.maxMessageBytes`, or whatever `body` throws. On any error the writer is unchanged.
    /// - Complexity: O(body bytes) at worst, from the shift.
    public mutating func appendMessage(
        field: FieldNumber, _ body: (inout WireWriter) throws(WireError) -> Void
    ) throws(WireError) {
        let mark = try beginMessage(field: field)
        do {
            try body(&self)
        } catch {
            abandonMessage(mark)
            throw error
        }
        try endMessage(mark)
    }

    /// Opens a nested message: writes the tag and a one-byte length slot. Everything appended until the matching
    /// ``endMessage(_:)`` or ``abandonMessage(_:)`` is the message body. For a body that cannot be a closure, such as one
    /// written by a `Codable` container.
    ///
    /// - Precondition: marks are closed in the reverse order they were opened.
    /// - Throws: ``WireError/depthExceeded(limit:at:)`` past `limits.maxDepth`; the writer is unchanged.
    public mutating func beginMessage(field: FieldNumber) throws(WireError) -> MessageMark {
        guard depth < limits.maxDepth else { throw .depthExceeded(limit: limits.maxDepth, at: bytes.count) }
        let rollback = bytes.count
        appendTag(field, .lengthDelimited)
        let slot = bytes.count
        bytes.append(0)
        depth += 1
        return MessageMark(rollback: rollback, slot: slot)
    }

    /// Closes the message `mark` opened, writing its minimal length prefix. A body of 128 bytes or more shifts once to
    /// widen the slot.
    /// - Throws: ``WireError/messageTooLarge(limit:)`` if the body exceeds `limits.maxMessageBytes`. The message is then
    ///   removed, as if it had been abandoned.
    /// - Complexity: O(body bytes) at worst, from the shift.
    public mutating func endMessage(_ mark: MessageMark) throws(WireError) {
        depth -= 1
        let slot = mark.slot
        let length = bytes.count - slot - 1
        guard length <= limits.maxMessageBytes else {
            bytes.removeSubrange(mark.rollback...)
            throw .messageTooLarge(limit: limits.maxMessageBytes)
        }
        guard length >= 0x80 else {
            bytes[slot] = UInt8(length)
            return
        }
        let width = Self.varintWidth(UInt64(length))
        bytes.insert(contentsOf: repeatElement(0, count: width - 1), at: slot + 1)
        var rest = UInt64(length)
        for index in 0 ..< width {
            let low = UInt8(truncatingIfNeeded: rest & 0x7F)
            rest >>= 7
            bytes[slot + index] = index == width - 1 ? low : low | 0x80
        }
    }

    /// Discards the message `mark` opened and everything written since, and releases its depth.
    public mutating func abandonMessage(_ mark: MessageMark) {
        depth -= 1
        bytes.removeSubrange(mark.rollback...)
    }

    /// The number of bytes `value` takes as a varint, 1 through 10.
    @usableFromInline static func varintWidth(_ value: UInt64) -> Int {
        (63 - (value | 1).leadingZeroBitCount) / 7 + 1
    }
}

extension WireWriter {
    /// Writes a nested message as ``appendMessage(field:_:)`` does, unless `body` writes nothing: then nothing is written.
    /// For a non-optional message field, whose empty value is its default and so is left out.
    public mutating func appendNonEmptyMessage(
        field: FieldNumber, _ body: (inout WireWriter) throws(WireError) -> Void
    ) throws(WireError) {
        let mark = try beginMessage(field: field)
        do {
            try body(&self)
        } catch {
            abandonMessage(mark)
            throw error
        }
        if bytes.count == mark.slot + 1 {
            abandonMessage(mark)
        } else {
            try endMessage(mark)
        }
    }
}
