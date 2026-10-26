/// The three-bit wire type in the low bits of every tag. It says how many bytes the payload takes, never what it means:
/// `int32`, `sint32` and `bool` are all `.varint`.
public enum WireType: UInt8, Sendable, CaseIterable {
    case varint = 0
    case fixed64 = 1
    case lengthDelimited = 2
    /// Deprecated group delimiters. They still appear on the wire in proto2 data, so a reader must skip them.
    case startGroup = 3
    case endGroup = 4
    case fixed32 = 5
}
