public import AemiProtobufCore

extension FileDescriptorSet {
    /// Decodes a `FileDescriptorSet` and checks its internal references.
    /// - Throws: ``DescriptorError/wire(_:)`` for malformed bytes, ``DescriptorError/oneofIndexOutOfRange(message:field:index:)``
    ///   for a field that names a oneof its message does not declare.
    public static func decode(from bytes: [UInt8]) throws(DescriptorError) -> FileDescriptorSet {
        let set: FileDescriptorSet
        do throws(WireError) { set = try decodeWire(from: bytes) } catch { throw .wire(error) }
        try set.checkReferences()
        return set
    }

    private static func decodeWire(from bytes: [UInt8]) throws(WireError) -> FileDescriptorSet {
        try WireReader.withReader(over: bytes) { r throws(WireError) in
            var set = FileDescriptorSet()
            while let tag = try r.nextTag() {
                if tag.fieldNumber == 1 && tag.wireType == .lengthDelimited {
                    let file = try r.readNested(FileDescriptor.self)
                    set.files.append(file)
                } else {
                    try r.skipField(tag)
                }
            }
            return set
        }
    }

    public func encode() throws(WireError) -> [UInt8] {
        var writer = WireWriter()
        for file in files {
            try writer.appendMessage(field: 1) { w throws(WireError) in
                try file.encode(into: &w)
            }
        }
        return writer.bytes
    }
}
