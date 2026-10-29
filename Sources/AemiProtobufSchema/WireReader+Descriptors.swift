import AemiProtobufCore

extension WireReader {
    /// Reads a length-delimited nested message as `type`.
    mutating func readNested<D: WireDecodableDescriptor>(_ type: D.Type) throws(WireError) -> D {
        try readMessage { r throws(WireError) in try D.decode(from: &r) }
    }

    /// Reads a `DescriptorProto.ReservedRange`, an `ExtensionRange` or an `EnumReservedRange`.
    mutating func readRange() throws(WireError) -> DescriptorRange {
        try readMessage { r throws(WireError) in
            var range = DescriptorRange()
            while let tag = try r.nextTag() {
                switch (tag.fieldNumber.rawValue, tag.wireType) {
                    case (1, .varint): range.start = try r.readInt32()
                    case (2, .varint): range.end = try r.readInt32()
                    case (3, .lengthDelimited): range.options = try r.readBytes()
                    default: try r.skipField(tag)
                }
            }
            return range
        }
    }
}
