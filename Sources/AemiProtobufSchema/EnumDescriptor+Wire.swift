public import AemiProtobufCore

extension EnumDescriptor: WireDecodableDescriptor {
    public static func decode(from reader: inout WireReader) throws(WireError) -> EnumDescriptor {
        try reader.readDescriptor(EnumDescriptor()) { (d: inout EnumDescriptor, tag, r) throws(WireError) -> Bool in
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): d.name = try r.readString()
                case (2, .lengthDelimited): d.values.append(try r.readNested(EnumValueDescriptor.self))
                case (3, .lengthDelimited): d.options = try r.readBytes()
                case (4, .lengthDelimited): d.reservedRanges.append(try r.readRange())
                case (5, .lengthDelimited): d.reservedNames.append(try r.readString())
                default: return false
            }
            return true
        }
    }

    public func encode(into writer: inout WireWriter) throws(WireError) {
        writer.appendField(1, nonEmpty: name)
        try writer.appendMessages(2, values) { v, w throws(WireError) in v.encode(into: &w) }
        writer.appendField(3, raw: options)
        try writer.appendMessages(4, reservedRanges) { r, w throws(WireError) in r.encode(into: &w) }
        for reserved in reservedNames { writer.appendField(5, reserved) }
        writer.appendUnknownFields(unknownFields)
    }
}
