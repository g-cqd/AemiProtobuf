public import AemiProtobufCore

extension EnumValueDescriptor: WireDecodableDescriptor {
    public static func decode(from reader: inout WireReader) throws(WireError) -> EnumValueDescriptor {
        try reader.readDescriptor(EnumValueDescriptor()) {
            (d: inout EnumValueDescriptor, tag, r) throws(WireError) -> Bool in
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): d.name = try r.readString()
                case (2, .varint): d.number = try r.readInt32()
                case (3, .lengthDelimited): d.options = try r.readBytes()
                default: return false
            }
            return true
        }
    }

    /// The number is written even when it is 0: protoc sets it on every value.
    public func encode(into writer: inout WireWriter) {
        writer.appendField(1, nonEmpty: name)
        writer.appendField(2, number)
        writer.appendField(3, raw: options)
        writer.appendUnknownFields(unknownFields)
    }
}
