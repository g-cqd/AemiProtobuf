public import AemiProtobufCore

extension Array: AemiProtoFastEncodable where Element: AemiProtoFastEncodable {
    public func __aepbEncode(into writer: inout WireWriter) throws(WireError) {
        for element in self {
            try writer.appendMessage(field: 1) { w throws(WireError) in
                try element.__aepbEncode(into: &w)
            }
        }
    }
}

extension Array: AemiProtoFastDecodable where Element: AemiProtoFastDecodable {
    public static func __aepbDecode(from reader: inout WireReader) throws(WireError) -> [Element] {
        var elements: [Element] = []
        while let tag = try reader.nextTag() {
            if tag.fieldNumber == 1 && tag.wireType == .lengthDelimited {
                let el = try reader.readMessage { r throws(WireError) in
                    try Element.__aepbDecode(from: &r)
                }
                elements.append(el)
            } else {
                try reader.skipField(tag)
            }
        }
        return elements
    }
}
