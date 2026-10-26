public import AemiProtobufCore

/// A type that can directly decode its fields from a `WireReader` without `Codable` container overhead.
public protocol AemiProtoFastDecodable {
    static func __aepbDecode(from reader: inout WireReader) throws(WireError) -> Self
}
