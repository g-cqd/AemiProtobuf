import AemiProtobuf

/// A message that is fast-path only: it is not `Codable`, so only the fast-path overloads of the coders accept it.
struct FastOnly: AemiProtoFastEncodable, AemiProtoFastDecodable, Equatable {
    var id: Int64 = 0
    var name = ""

    func __aepbEncode(into w: inout WireWriter) throws(WireError) {
        if id != 0 {
            w.appendTag(1, .varint)
            w.appendVarint(UInt64(bitPattern: id))
        }
        if !name.isEmpty {
            w.appendTag(2, .lengthDelimited)
            w.appendString(name)
        }
    }

    static func __aepbDecode(from r: inout WireReader) throws(WireError) -> FastOnly {
        var out = FastOnly()
        while let tag = try r.nextTag() {
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .varint): out.id = Int64(bitPattern: try r.readVarint())
                case (2, .lengthDelimited): out.name = try r.readString()
                default: try r.skipField(tag)
            }
        }
        return out
    }
}
