import AemiProtobufCore

/// One field occurrence in a message, found by the index pass. A length-delimited payload is not copied: `payload` is its
/// offset in the buffer and `length` its size.
struct _ProtobufFieldEntry {
    let number: UInt32
    let wireType: WireType
    /// The varint value or fixed-width bits; for a length-delimited field, the payload's offset in the buffer.
    let payload: UInt64
    /// The payload size of a length-delimited field; 0 otherwise.
    let length: Int

    /// The value as a scalar, or `nil` for a length-delimited field and a group.
    var scalar: _WireScalar? {
        switch wireType {
            case .varint: .varint(payload)
            case .fixed32: .fixed32(UInt32(truncatingIfNeeded: payload))
            case .fixed64: .fixed64(payload)
            case .lengthDelimited, .startGroup, .endGroup: nil
        }
    }

    /// Where a length-delimited payload lies in the buffer. `Int(exactly:)` cannot fail for an entry the index made.
    var range: Range<Int> {
        let lower = Int(truncatingIfNeeded: payload)
        return lower ..< lower + length
    }
}
