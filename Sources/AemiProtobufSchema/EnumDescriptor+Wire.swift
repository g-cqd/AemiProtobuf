public import AemiProtobufCore

extension EnumDescriptor: WireDecodableDescriptor {
    public static func decode(from reader: inout WireReader) throws(WireError) -> EnumDescriptor {
        var desc = EnumDescriptor()
        while let tag = try reader.nextTag() {
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): desc.name = try reader.readString()
                case (2, .lengthDelimited):
                    let v = try reader.readNested(EnumValueDescriptor.self)
                    desc.values.append(v)
                default: try reader.skipField(tag)
            }
        }
        return desc
    }

    public func encode(into writer: inout WireWriter) throws(WireError) {
        if !name.isEmpty {
            writer.appendTag(1, .lengthDelimited)
            writer.appendString(name)
        }
        for v in values {
            try writer.appendMessage(field: 2) { w throws(WireError) in
                try v.encode(into: &w)
            }
        }
    }
}
