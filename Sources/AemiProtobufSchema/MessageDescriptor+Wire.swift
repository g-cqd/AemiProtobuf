public import AemiProtobufCore

extension MessageDescriptor: WireDecodableDescriptor {
    public static func decode(from reader: inout WireReader) throws(WireError) -> MessageDescriptor {
        try reader.readDescriptor(MessageDescriptor()) {
            (d: inout MessageDescriptor, tag, r) throws(WireError) -> Bool in
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): d.name = try r.readString()
                case (2, .lengthDelimited): d.fields.append(try r.readNested(FieldDescriptor.self))
                case (3, .lengthDelimited): d.nestedMessages.append(try r.readNested(MessageDescriptor.self))
                case (4, .lengthDelimited): d.nestedEnums.append(try r.readNested(EnumDescriptor.self))
                case (5, .lengthDelimited): d.extensionRanges.append(try r.readRange())
                case (6, .lengthDelimited): d.extensions.append(try r.readNested(FieldDescriptor.self))
                case (7, .lengthDelimited): d.options = try r.readBytes()
                case (8, .lengthDelimited): d.oneofs.append(try r.readNested(OneofDescriptor.self))
                case (9, .lengthDelimited): d.reservedRanges.append(try r.readRange())
                case (10, .lengthDelimited): d.reservedNames.append(try r.readString())
                default: return false
            }
            return true
        }
    }

    public func encode(into writer: inout WireWriter) throws(WireError) {
        writer.appendField(1, nonEmpty: name)
        try writer.appendMessages(2, fields) { f, w throws(WireError) in try f.encode(into: &w) }
        try writer.appendMessages(3, nestedMessages) { m, w throws(WireError) in try m.encode(into: &w) }
        try writer.appendMessages(4, nestedEnums) { e, w throws(WireError) in try e.encode(into: &w) }
        try writer.appendMessages(5, extensionRanges) { r, w throws(WireError) in r.encode(into: &w) }
        try writer.appendMessages(6, extensions) { f, w throws(WireError) in try f.encode(into: &w) }
        writer.appendField(7, raw: options)
        try writer.appendMessages(8, oneofs) { o, w throws(WireError) in o.encode(into: &w) }
        try writer.appendMessages(9, reservedRanges) { r, w throws(WireError) in r.encode(into: &w) }
        for reserved in reservedNames { writer.appendField(10, reserved) }
        writer.appendUnknownFields(unknownFields)
    }
}
