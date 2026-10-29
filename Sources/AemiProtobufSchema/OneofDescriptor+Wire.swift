public import AemiProtobufCore

extension OneofDescriptor: WireDecodableDescriptor {
    public static func decode(from reader: inout WireReader) throws(WireError) -> OneofDescriptor {
        try reader.readDescriptor(OneofDescriptor()) { (d: inout OneofDescriptor, tag, r) throws(WireError) -> Bool in
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): d.name = try r.readString()
                case (2, .lengthDelimited): d.options = try r.readBytes()
                default: return false
            }
            return true
        }
    }

    public func encode(into writer: inout WireWriter) {
        writer.appendField(1, nonEmpty: name)
        writer.appendField(2, raw: options)
        writer.appendUnknownFields(unknownFields)
    }
}
