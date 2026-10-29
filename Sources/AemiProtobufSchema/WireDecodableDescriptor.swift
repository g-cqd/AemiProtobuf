import AemiProtobufCore

/// A descriptor that reads itself from a wire message, keeping the fields it does not model.
protocol WireDecodableDescriptor {
    var unknownFields: UnknownFields { get set }
    static func decode(from reader: inout WireReader) throws(WireError) -> Self
}

extension WireReader {
    /// Reads every field of the message into `initial`: `field` takes the ones `D` models and returns false for the rest,
    /// which are kept in `unknownFields`.
    mutating func readDescriptor<D: WireDecodableDescriptor>(
        _ initial: D, _ field: (inout D, FieldTag, inout WireReader) throws(WireError) -> Bool
    ) throws(WireError) -> D {
        var descriptor = initial
        while let tag = try nextTag() {
            if try !field(&descriptor, tag, &self) { try readUnknownField(tag, into: &descriptor.unknownFields) }
        }
        return descriptor
    }
}
