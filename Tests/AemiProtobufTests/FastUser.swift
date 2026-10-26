import AemiProtobuf
import AemiProtobufCore

struct FastUser: Codable, Equatable, AemiProtoFastEncodable, AemiProtoFastDecodable {
    var id: Int64 = 0
    var name: String = ""
    var email: String = ""
    var active: Bool = false
    var score: Double = 0.0
    var tags: [String] = []
    var samples: [Int32] = []
    var address: FastAddress? = nil
    var delta: Int32 = 0
    var stamp: UInt64 = 0

    func __aepbEncode(into writer: inout WireWriter) throws(WireError) {
        if id != 0 {
            writer.appendTag(1, .varint)
            writer.appendVarint(UInt64(bitPattern: id))
        }
        if !name.isEmpty {
            writer.appendTag(2, .lengthDelimited)
            writer.appendString(name)
        }
        if !email.isEmpty {
            writer.appendTag(3, .lengthDelimited)
            writer.appendString(email)
        }
        if active {
            writer.appendTag(4, .varint)
            writer.appendVarint(1)
        }
        if score != 0.0 {
            writer.appendTag(5, .fixed64)
            writer.appendDouble(score)
        }
        for tag in tags {
            writer.appendTag(6, .lengthDelimited)
            writer.appendString(tag)
        }
        if !samples.isEmpty {
            try writer.appendMessage(field: 7) { w throws(WireError) in
                for s in samples { w.appendInt32(s) }
            }
        }
        if let addr = address {
            try writer.appendMessage(field: 8) { w throws(WireError) in
                try addr.__aepbEncode(into: &w)
            }
        }
        if delta != 0 {
            writer.appendTag(9, .varint)
            writer.appendVarint(UInt64(ZigZag.encode(delta)))
        }
        if stamp != 0 {
            writer.appendTag(10, .fixed64)
            writer.appendFixed64(stamp)
        }
    }

    static func __aepbDecode(from reader: inout WireReader) throws(WireError) -> FastUser {
        var user = FastUser()
        while let tag = try reader.nextTag() {
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .varint): user.id = Int64(bitPattern: try reader.readVarint())
                case (2, .lengthDelimited): user.name = try reader.readString()
                case (3, .lengthDelimited): user.email = try reader.readString()
                case (4, .varint): user.active = try reader.readVarint() != 0
                case (5, .fixed64): user.score = try reader.readDouble()
                case (6, .lengthDelimited): user.tags.append(try reader.readString())
                case (7, .lengthDelimited):
                    try reader.readMessage { r throws(WireError) in
                        while !r.isAtEnd { user.samples.append(try r.readInt32()) }
                    }
                case (8, .lengthDelimited):
                    user.address = try reader.readMessage { r throws(WireError) in
                        try FastAddress.__aepbDecode(from: &r)
                    }
                case (9, .varint): user.delta = ZigZag.decode(UInt32(truncatingIfNeeded: try reader.readVarint()))
                case (10, .fixed64): user.stamp = try reader.readFixed64()
                default: try reader.skipField(tag)
            }
        }
        return user
    }
}
