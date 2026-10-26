import AemiProtobuf
import AemiProtobufCore

struct FastAddress: Codable, Equatable, AemiProtoFastEncodable, AemiProtoFastDecodable {
    var street: String = ""
    var city: String = ""
    var zip: Int32 = 0

    func __aepbEncode(into writer: inout WireWriter) throws(WireError) {
        if !street.isEmpty {
            writer.appendTag(1, .lengthDelimited)
            writer.appendString(street)
        }
        if !city.isEmpty {
            writer.appendTag(2, .lengthDelimited)
            writer.appendString(city)
        }
        if zip != 0 {
            writer.appendTag(3, .varint)
            writer.appendInt32(zip)
        }
    }

    static func __aepbDecode(from reader: inout WireReader) throws(WireError) -> FastAddress {
        var addr = FastAddress()
        while let tag = try reader.nextTag() {
            switch (tag.fieldNumber.rawValue, tag.wireType) {
                case (1, .lengthDelimited): addr.street = try reader.readString()
                case (2, .lengthDelimited): addr.city = try reader.readString()
                case (3, .varint): addr.zip = try reader.readInt32()
                default: try reader.skipField(tag)
            }
        }
        return addr
    }
}
