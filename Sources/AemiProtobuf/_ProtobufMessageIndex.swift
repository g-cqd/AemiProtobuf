import AemiProtobufCore

/// Every field occurrence of one message, in wire order, so a keyed container can ask for any field in any order.
///
/// One pass reads the tags and skips the payloads; nothing is copied. Memory is one 24-byte entry per field occurrence, at
/// most one entry per two input bytes, so within `WireLimits.maxMessageBytes` the index is at most 12 times the input.
/// Several ranges are one message: concatenated serialized messages merge, as the protobuf specification says.
struct _ProtobufMessageIndex {
    let entries: [_ProtobufFieldEntry]

    /// - Parameters:
    ///   - bytes: the buffer the ranges index into.
    ///   - ranges: the serialized pieces of the message, in order.
    ///   - depth: how many messages deep the first byte of each range is.
    ///   - limits: nesting and size bounds.
    /// - Throws: a ``WireError`` for malformed bytes or an exceeded limit. Groups are skipped, not indexed.
    /// - Complexity: O(total bytes).
    init(bytes: [UInt8], ranges: [Range<Int>], depth: Int, limits: WireLimits) throws(WireError) {
        var entries: [_ProtobufFieldEntry] = []
        for range in ranges {
            try WireReader.withReader(over: bytes, in: range, depth: depth, limits: limits) { r throws(WireError) in
                while let tag = try r.nextTag() {
                    let number = tag.fieldNumber.rawValue
                    switch tag.wireType {
                        case .varint:
                            entries.append(
                                .init(number: number, wireType: .varint, payload: try r.readVarint(), length: 0))
                        case .fixed32:
                            entries.append(
                                .init(
                                    number: number, wireType: .fixed32, payload: UInt64(try r.readFixed32()), length: 0)
                            )
                        case .fixed64:
                            entries.append(
                                .init(number: number, wireType: .fixed64, payload: try r.readFixed64(), length: 0))
                        case .lengthDelimited:
                            let payload = try r.readPayloadRange()
                            entries.append(
                                .init(
                                    number: number, wireType: .lengthDelimited, payload: UInt64(payload.lowerBound),
                                    length: payload.count))
                        case .startGroup, .endGroup:
                            try r.skipField(tag)
                    }
                }
            }
        }
        self.entries = entries
    }

    /// The occurrences of field `number`, in wire order.
    func entries(for number: UInt32) -> [_ProtobufFieldEntry] {
        entries.filter { $0.number == number }
    }

    /// The last occurrence of field `number`: for a singular field the last one wins.
    func last(for number: UInt32) -> _ProtobufFieldEntry? {
        entries.last { $0.number == number }
    }
}
