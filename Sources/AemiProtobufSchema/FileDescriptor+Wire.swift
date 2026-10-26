public import AemiProtobufCore

extension FileDescriptor: WireDecodableDescriptor {
    public static func decode(from reader: inout WireReader) throws(WireError) -> FileDescriptor {
        var file = FileDescriptor()
        while let tag = try reader.nextTag() {
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): file.name = try reader.readString()
                case (2, .lengthDelimited): file.package = try reader.readString()
                case (4, .lengthDelimited):
                    let m = try reader.readNested(MessageDescriptor.self)
                    file.messages.append(m)
                case (5, .lengthDelimited):
                    let e = try reader.readNested(EnumDescriptor.self)
                    file.enums.append(e)
                case (12, .lengthDelimited): file.syntax = try reader.readString()
                default: try reader.skipField(tag)
            }
        }
        return file
    }

    public func encode(into writer: inout WireWriter) throws(WireError) {
        if !name.isEmpty {
            writer.appendTag(1, .lengthDelimited)
            writer.appendString(name)
        }
        if !package.isEmpty {
            writer.appendTag(2, .lengthDelimited)
            writer.appendString(package)
        }
        for m in messages {
            try writer.appendMessage(field: 4) { w throws(WireError) in
                try m.encode(into: &w)
            }
        }
        for e in enums {
            try writer.appendMessage(field: 5) { w throws(WireError) in
                try e.encode(into: &w)
            }
        }
        if !syntax.isEmpty {
            writer.appendTag(12, .lengthDelimited)
            writer.appendString(syntax)
        }
    }
}
