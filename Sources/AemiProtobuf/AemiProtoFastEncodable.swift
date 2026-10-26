public import AemiProtobufCore

/// A type that can directly encode its fields into a `WireWriter` without `Codable` container overhead.
public protocol AemiProtoFastEncodable {
    func __aepbEncode(into writer: inout WireWriter) throws(WireError)
}
