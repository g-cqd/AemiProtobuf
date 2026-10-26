public import AemiProtobufCore

extension FieldDescriptor: WireDecodableDescriptor {
    public static func decode(from reader: inout WireReader) throws(WireError) -> FieldDescriptor {
        var field = FieldDescriptor()
        while let tag = try reader.nextTag() {
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): field.name = try reader.readString()
                case (3, .varint): field.number = try reader.readInt32()
                case (4, .varint):
                    if let l = FieldLabel(rawValue: try reader.readInt32()) { field.label = l }
                case (5, .varint):
                    if let t = FieldType(rawValue: try reader.readInt32()) { field.type = t }
                case (6, .lengthDelimited): field.typeName = try reader.readString()
                case (9, .varint): field.oneofIndex = try reader.readInt32()
                case (17, .varint): field.proto3Optional = try reader.readVarint() != 0
                case (10, .lengthDelimited): field.jsonName = try reader.readString()
                default: try reader.skipField(tag)
            }
        }
        return field
    }

    public func encode(into writer: inout WireWriter) throws(WireError) {
        if !name.isEmpty {
            writer.appendTag(1, .lengthDelimited)
            writer.appendString(name)
        }
        if number != 0 {
            writer.appendTag(3, .varint)
            writer.appendInt32(number)
        }
        writer.appendTag(4, .varint)
        writer.appendInt32(label.rawValue)
        writer.appendTag(5, .varint)
        writer.appendInt32(type.rawValue)
        if !typeName.isEmpty {
            writer.appendTag(6, .lengthDelimited)
            writer.appendString(typeName)
        }
        if let oneofIndex {
            writer.appendTag(9, .varint)
            writer.appendInt32(oneofIndex)
        }
        if !jsonName.isEmpty {
            writer.appendTag(10, .lengthDelimited)
            writer.appendString(jsonName)
        }
        if proto3Optional {
            writer.appendTag(17, .varint)
            writer.appendVarint(1)
        }
    }
}
