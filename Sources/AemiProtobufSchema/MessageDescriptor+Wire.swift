public import AemiProtobufCore

extension MessageDescriptor: WireDecodableDescriptor {
    public static func decode(from reader: inout WireReader) throws(WireError) -> MessageDescriptor {
        var msg = MessageDescriptor()
        while let tag = try reader.nextTag() {
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): msg.name = try reader.readString()
                case (2, .lengthDelimited):
                    let f = try reader.readNested(FieldDescriptor.self)
                    msg.fields.append(f)
                case (3, .lengthDelimited):
                    let nested = try reader.readNested(MessageDescriptor.self)
                    msg.nestedMessages.append(nested)
                case (4, .lengthDelimited):
                    let e = try reader.readNested(EnumDescriptor.self)
                    msg.nestedEnums.append(e)
                case (8, .lengthDelimited):
                    let o = try reader.readNested(OneofDescriptor.self)
                    msg.oneofs.append(o)
                default: try reader.skipField(tag)
            }
        }
        return msg
    }

    public func encode(into writer: inout WireWriter) throws(WireError) {
        if !name.isEmpty {
            writer.appendTag(1, .lengthDelimited)
            writer.appendString(name)
        }
        for f in fields {
            try writer.appendMessage(field: 2) { w throws(WireError) in
                try f.encode(into: &w)
            }
        }
        for nested in nestedMessages {
            try writer.appendMessage(field: 3) { w throws(WireError) in
                try nested.encode(into: &w)
            }
        }
        for e in nestedEnums {
            try writer.appendMessage(field: 4) { w throws(WireError) in
                try e.encode(into: &w)
            }
        }
        for o in oneofs {
            try writer.appendMessage(field: 8) { w throws(WireError) in o.encode(into: &w) }
        }
    }
}
