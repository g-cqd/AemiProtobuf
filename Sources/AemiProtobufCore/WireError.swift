/// Why a read or a write was refused. Each case that comes from input carries a byte offset: where the item that failed
/// starts, with the exceptions each case names.
public enum WireError: Error, Equatable, Sendable {
    /// The input ended inside a varint or a fixed-width value (`at` is where it started), or with a group still open (`at`
    /// is where its end-group tag was expected).
    case truncated(at: Int)
    /// A varint longer than ten bytes, or whose tenth byte has bits above bit 63. `at` is the varint's first byte.
    case malformedVarint(at: Int)
    /// A tag for field 0, or a tag above 32 bits.
    case invalidTag(UInt64, at: Int)
    /// A tag with wire type 6 or 7.
    case invalidWireType(UInt8, at: Int)
    /// A length prefix larger than the bytes that remain (or than `Int.max`).
    case lengthOutOfBounds(declared: UInt64, remaining: Int, at: Int)
    /// A string field whose bytes are not well-formed UTF-8 (RFC 3629). `at` is where the string's bytes start.
    case invalidUTF8(at: Int)
    /// An end-group tag that does not close the innermost open group.
    case endGroupMismatch(expected: FieldNumber, found: FieldNumber, at: Int)
    /// An end-group tag with no open group.
    case unexpectedEndGroup(at: Int)
    /// More nested messages or groups than ``WireLimits/maxDepth``.
    case depthExceeded(limit: Int, at: Int)
    /// A buffer or a message larger than ``WireLimits/maxMessageBytes``.
    case messageTooLarge(limit: Int)
}
