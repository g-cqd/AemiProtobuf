import AemiProtobufCore

extension WireReader {
    /// Reads a length-delimited nested message as `type`.
    mutating func readNested<D: WireDecodableDescriptor>(_ type: D.Type) throws(WireError) -> D {
        try readMessage { r throws(WireError) in try D.decode(from: &r) }
    }
}
