public import AemiProtobufCore

/// A type that can directly decode its fields from a `WireReader` without `Codable` container overhead.
public protocol AemiProtoFastDecodable {
    static func __aepbDecode(from reader: inout WireReader) throws(WireError) -> Self

    /// Merges the message in `reader` into `self`, as the encoding guide merges a message given more than once: a scalar
    /// takes the last value, a repeated field appends, a nested message merges.
    mutating func __aepbMerge(from reader: inout WireReader) throws(WireError)
}

extension AemiProtoFastDecodable {
    /// For a hand-written type with no merge of its own: the later occurrence replaces the earlier one.
    public mutating func __aepbMerge(from reader: inout WireReader) throws(WireError) {
        self = try Self.__aepbDecode(from: &reader)
    }
}
