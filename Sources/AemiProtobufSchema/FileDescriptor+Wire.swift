public import AemiProtobufCore

extension FileDescriptor: WireDecodableDescriptor {
    public static func decode(from reader: inout WireReader) throws(WireError) -> FileDescriptor {
        // A proto2 file has no `syntax` field; an absent one is proto2, not the initializer's proto3.
        try reader.readDescriptor(FileDescriptor(syntax: "")) {
            (d: inout FileDescriptor, tag, r) throws(WireError) -> Bool in
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): d.name = try r.readString()
                case (2, .lengthDelimited): d.package = try r.readString()
                case (3, .lengthDelimited): d.dependencies.append(try r.readString())
                case (4, .lengthDelimited): d.messages.append(try r.readNested(MessageDescriptor.self))
                case (5, .lengthDelimited): d.enums.append(try r.readNested(EnumDescriptor.self))
                case (6, .lengthDelimited): d.services.append(try r.readNested(ServiceDescriptor.self))
                case (7, .lengthDelimited): d.extensions.append(try r.readNested(FieldDescriptor.self))
                case (8, .lengthDelimited): d.options = try r.readBytes()
                case (9, .lengthDelimited): d.sourceCodeInfo = try r.readBytes()
                case (10, .varint): d.publicDependencies.append(try r.readInt32())
                case (11, .varint): d.weakDependencies.append(try r.readInt32())
                case (12, .lengthDelimited): d.syntax = try r.readString()
                case (14, .varint): d.edition = try r.readInt32()
                default: return false
            }
            return true
        }
    }

    /// `syntax` "proto2" is written only when it was read (a proto2 file may or may not spell it); an empty one is not.
    public func encode(into writer: inout WireWriter) throws(WireError) {
        writer.appendField(1, nonEmpty: name)
        writer.appendField(2, nonEmpty: package)
        for dependency in dependencies { writer.appendField(3, dependency) }
        try writer.appendMessages(4, messages) { m, w throws(WireError) in try m.encode(into: &w) }
        try writer.appendMessages(5, enums) { e, w throws(WireError) in try e.encode(into: &w) }
        try writer.appendMessages(6, services) { s, w throws(WireError) in try s.encode(into: &w) }
        try writer.appendMessages(7, extensions) { f, w throws(WireError) in try f.encode(into: &w) }
        writer.appendField(8, raw: options)
        writer.appendField(9, raw: sourceCodeInfo)
        for index in publicDependencies { writer.appendField(10, index) }
        for index in weakDependencies { writer.appendField(11, index) }
        writer.appendField(12, nonEmpty: syntax)
        writer.appendField(14, edition)
        writer.appendUnknownFields(unknownFields)
    }
}
