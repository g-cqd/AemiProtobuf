public import AemiProtobufCore

extension OneofDescriptor: WireDecodableDescriptor {
    /// Decodes a `OneofDescriptorProto`; unknown fields are skipped.
    public static func decode(from reader: inout WireReader) throws(WireError) -> OneofDescriptor {
        var oneof = OneofDescriptor()
        while let tag = try reader.nextTag() {
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): oneof.name = try reader.readString()
                default: try reader.skipField(tag)
            }
        }
        return oneof
    }

    /// Encodes as a `OneofDescriptorProto`.
    public func encode(into writer: inout WireWriter) {
        writer.appendTag(1, .lengthDelimited)
        writer.appendString(name)
    }
}
