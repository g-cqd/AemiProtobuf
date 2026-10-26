public import AemiProtobufCore

extension EnumValueDescriptor: WireDecodableDescriptor {
    public static func decode(from reader: inout WireReader) throws(WireError) -> EnumValueDescriptor {
        var val = EnumValueDescriptor()
        while let tag = try reader.nextTag() {
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): val.name = try reader.readString()
                case (2, .varint): val.number = try reader.readInt32()
                default: try reader.skipField(tag)
            }
        }
        return val
    }

    public func encode(into writer: inout WireWriter) throws(WireError) {
        if !name.isEmpty {
            writer.appendTag(1, .lengthDelimited)
            writer.appendString(name)
        }
        if number != 0 {
            writer.appendTag(2, .varint)
            writer.appendInt32(number)
        }
    }
}
