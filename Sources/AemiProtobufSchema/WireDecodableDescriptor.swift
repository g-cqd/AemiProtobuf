import AemiProtobufCore

/// A descriptor that reads itself from a wire message.
protocol WireDecodableDescriptor {
    static func decode(from reader: inout WireReader) throws(WireError) -> Self
}
