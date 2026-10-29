public import AemiProtobufCore

extension FieldDescriptor: WireDecodableDescriptor {
    public static func decode(from reader: inout WireReader) throws(WireError) -> FieldDescriptor {
        try reader.readDescriptor(FieldDescriptor()) { (d: inout FieldDescriptor, tag, r) throws(WireError) -> Bool in
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): d.name = try r.readString()
                case (2, .lengthDelimited): d.extendee = try r.readString()
                case (3, .varint): d.number = try r.readInt32()
                case (4, .varint):
                    if let l = FieldLabel(rawValue: try r.readInt32()) { d.label = l }
                case (5, .varint):
                    if let t = FieldType(rawValue: try r.readInt32()) { d.type = t }
                case (6, .lengthDelimited): d.typeName = try r.readString()
                case (7, .lengthDelimited): d.defaultValue = try r.readString()
                case (8, .lengthDelimited): d.options = try r.readBytes()
                case (9, .varint): d.oneofIndex = try r.readInt32()
                case (10, .lengthDelimited): d.jsonName = try r.readString()
                case (17, .varint): d.proto3Optional = try r.readVarint() != 0
                default: return false
            }
            return true
        }
    }

    public func encode(into writer: inout WireWriter) throws(WireError) {
        writer.appendField(1, nonEmpty: name)
        writer.appendField(2, nonEmpty: extendee)
        if number != 0 { writer.appendField(3, number) }
        writer.appendField(4, label.rawValue)
        writer.appendField(5, type.rawValue)
        writer.appendField(6, nonEmpty: typeName)
        writer.appendField(7, defaultValue)
        writer.appendField(8, raw: options)
        writer.appendField(9, oneofIndex)
        writer.appendField(10, nonEmpty: jsonName)
        if proto3Optional { writer.appendField(17, true) }
        writer.appendUnknownFields(unknownFields)
    }
}
