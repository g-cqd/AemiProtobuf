public import AemiProtobufCore

extension MethodDescriptor: WireDecodableDescriptor {
    public static func decode(from reader: inout WireReader) throws(WireError) -> MethodDescriptor {
        try reader.readDescriptor(MethodDescriptor()) { (d: inout MethodDescriptor, tag, r) throws(WireError) -> Bool in
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): d.name = try r.readString()
                case (2, .lengthDelimited): d.inputType = try r.readString()
                case (3, .lengthDelimited): d.outputType = try r.readString()
                case (4, .lengthDelimited): d.options = try r.readBytes()
                case (5, .varint): d.clientStreaming = try r.readVarint() != 0
                case (6, .varint): d.serverStreaming = try r.readVarint() != 0
                default: return false
            }
            return true
        }
    }

    public func encode(into writer: inout WireWriter) {
        writer.appendField(1, nonEmpty: name)
        writer.appendField(2, nonEmpty: inputType)
        writer.appendField(3, nonEmpty: outputType)
        writer.appendField(4, raw: options)
        writer.appendField(5, clientStreaming)
        writer.appendField(6, serverStreaming)
        writer.appendUnknownFields(unknownFields)
    }
}
