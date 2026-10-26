import AemiProtobufCore

extension WireValidator {
    /// Checks the payload of a scalar, string, bytes or group field the tag has just announced, leaving the reader after it.
    func validatePayload(
        _ tag: FieldTag, field: FieldDescriptor, packed: Bool, reader: inout WireReader, bytes: [UInt8], depth: Int
    ) throws(WireError) -> WireValidationError? {
        if packed {
            let payload = try reader.readPayloadRange()
            let wire = Self.expectedWireType(for: field.type)
            // Offsets are those of the whole buffer, so an error inside the run points at its byte.
            try WireReader.withReader(over: bytes, in: payload, depth: depth, limits: limits) { run throws(WireError) in
                while !run.isAtEnd {
                    switch wire {
                        case .fixed32: _ = try run.readFixed32()
                        case .fixed64: _ = try run.readFixed64()
                        default: _ = try run.readVarint()
                    }
                }
            }
        } else if field.type == .string {
            do throws(WireError) {
                _ = try reader.readString()
            } catch {
                guard case .invalidUTF8(let offset) = error else { throw error }
                return .invalidUTF8(field: field.number, at: offset)
            }
        } else {
            try reader.skipField(tag)
        }
        return nil
    }
}
