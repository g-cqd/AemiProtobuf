public import AemiProtobufCore

extension ServiceDescriptor: WireDecodableDescriptor {
    public static func decode(from reader: inout WireReader) throws(WireError) -> ServiceDescriptor {
        try reader.readDescriptor(ServiceDescriptor()) {
            (d: inout ServiceDescriptor, tag, r) throws(WireError) -> Bool in
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): d.name = try r.readString()
                case (2, .lengthDelimited): d.methods.append(try r.readNested(MethodDescriptor.self))
                case (3, .lengthDelimited): d.options = try r.readBytes()
                default: return false
            }
            return true
        }
    }

    public func encode(into writer: inout WireWriter) throws(WireError) {
        writer.appendField(1, nonEmpty: name)
        try writer.appendMessages(2, methods) { m, w throws(WireError) in m.encode(into: &w) }
        writer.appendField(3, raw: options)
        writer.appendUnknownFields(unknownFields)
    }
}
