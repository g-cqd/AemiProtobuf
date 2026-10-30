import AemiProtobufCore

/// Writes ``DynamicValue`` scalars as a field type says. Each function returns `false`, writing nothing, when the value's case is
/// not the type's.
enum DynamicScalarWriter {
    /// Writes the tag and the value.
    static func write(_ value: DynamicValue, as type: FieldType, field: FieldNumber, into writer: inout WireWriter)
        -> Bool
    {
        guard fits(value, type) else { return false }
        writer.appendTag(field, DynamicDecoder.wireType(of: type))
        return payload(value, as: type, into: &writer)
    }

    /// Writes the value alone, as in a packed run.
    static func payload(_ value: DynamicValue, as type: FieldType, into writer: inout WireWriter) -> Bool {
        switch (type, value) {
            case (.int32, .int32(let v)), (.enum, .enumeration(let v)):
                writer.appendVarint(UInt64(bitPattern: Int64(v)))
            case (.sint32, .int32(let v)): writer.appendVarint(UInt64(ZigZag.encode(v)))
            case (.sfixed32, .int32(let v)): writer.appendFixed32(UInt32(bitPattern: v))
            case (.int64, .int64(let v)): writer.appendVarint(UInt64(bitPattern: v))
            case (.sint64, .int64(let v)): writer.appendVarint(ZigZag.encode(v))
            case (.sfixed64, .int64(let v)): writer.appendFixed64(UInt64(bitPattern: v))
            case (.uint32, .uint32(let v)): writer.appendVarint(UInt64(v))
            case (.fixed32, .uint32(let v)): writer.appendFixed32(v)
            case (.uint64, .uint64(let v)): writer.appendVarint(v)
            case (.fixed64, .uint64(let v)): writer.appendFixed64(v)
            case (.double, .double(let v)): writer.appendDouble(v)
            case (.float, .float(let v)): writer.appendFloat(v)
            case (.bool, .bool(let v)): writer.appendVarint(v ? 1 : 0)
            case (.string, .string(let v)): writer.appendString(v)
            case (.string, .bytes(let v)), (.bytes, .bytes(let v)): writer.appendBytes(v)
            default: return false
        }
        return true
    }

    private static func fits(_ value: DynamicValue, _ type: FieldType) -> Bool {
        switch (type, value) {
            case (.int32, .int32), (.sint32, .int32), (.sfixed32, .int32), (.enum, .enumeration), (.int64, .int64),
                (.sint64, .int64), (.sfixed64, .int64), (.uint32, .uint32), (.fixed32, .uint32), (.uint64, .uint64),
                (.fixed64, .uint64), (.double, .double), (.float, .float), (.bool, .bool), (.string, .string),
                (.string, .bytes), (.bytes, .bytes):
                true
            default: false
        }
    }
}
