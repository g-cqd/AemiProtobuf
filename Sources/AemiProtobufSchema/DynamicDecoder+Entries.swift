import AemiProtobufCore

extension DynamicDecoder {
    /// Reads one map entry into `field` of `node`. The entry is read in place, one level deeper; only a message value is queued.
    /// An absent key or value reads as its zero, a later entry with the same key replaces the earlier one, and an entry whose
    /// closed enumeration value has no case is kept whole as an unknown field.
    mutating func readEntry(
        _ field: DynamicField, _ entry: DynamicField.MapEntry, _ tag: FieldTag, from reader: inout WireReader,
        into node: Int
    ) throws(WireError) {
        let range = try reader.readPayloadRange()
        let isMessage = entry.value.type == .message
        var key: DynamicValue?
        var value: DynamicValue?
        var valueRanges: [Range<Int>] = []
        try WireReader.withReader(over: bytes, in: range, depth: nodes[node].depth + 1, limits: limits) {
            [bytes] (inner) throws(WireError) in
            while let next = try inner.nextTag() {
                let number = next.fieldNumber.rawValue
                if number == 1, next.wireType == Self.wireType(of: entry.key.type) {
                    key = try Self.scalar(
                        entry.key.type, from: &inner, validatingUTF8: entry.keyValidatesUTF8, bytes: bytes)
                } else if number == 2, isMessage, next.wireType == .lengthDelimited {
                    valueRanges.append(try inner.readPayloadRange())
                } else if number == 2, !isMessage, next.wireType == Self.wireType(of: entry.value.type) {
                    value = try Self.scalar(
                        entry.value.type, from: &inner, validatingUTF8: entry.valueValidatesUTF8, bytes: bytes)
                } else {
                    try inner.skipField(next)
                }
            }
        }
        if case .enumeration(let number)? = value, let closed = entry.valueClosedEnumValues, !closed.contains(number) {
            var writer = WireWriter()
            writer.appendTag(tag.fieldNumber, .lengthDelimited)
            writer.appendBytes(Array(bytes[range]))
            nodes[node].unknown.appendEncoded(writer.bytes)
            return
        }
        let resolvedKey = key ?? schema.defaultValue(of: entry.key, typeName: nil)
        let number = field.number
        if let replaced = nodes[node].mapChildren[number]?.removeValue(forKey: resolvedKey) {
            nodes[replaced].parent = nil
        }
        let empty = schema.defaultValue(of: entry.value, typeName: entry.valueTypeName)
        nodes[node].maps[number, default: [:]][resolvedKey] = value ?? empty
        guard !valueRanges.isEmpty else { return }
        let child = spawn(
            entry.valueTypeName, Link(parent: node, field: number, slot: .mapValue(resolvedKey)), ranges: valueRanges)
        nodes[node].mapChildren[number, default: [:]][resolvedKey] = child
    }

    /// The wire type a field of `type` is written with.
    static func wireType(of type: FieldType) -> WireType { WireValidator.expectedWireType(for: type) }

    /// Reads one scalar of `type`. A `string` that need not be UTF-8 and is not is kept as `.bytes`.
    static func scalar(
        _ type: FieldType, from reader: inout WireReader, validatingUTF8: Bool, bytes: [UInt8]
    ) throws(WireError) -> DynamicValue {
        switch type {
            case .int32: .int32(Int32(truncatingIfNeeded: try reader.readVarint()))
            case .int64: .int64(Int64(bitPattern: try reader.readVarint()))
            case .uint32: .uint32(UInt32(truncatingIfNeeded: try reader.readVarint()))
            case .uint64: .uint64(try reader.readVarint())
            case .sint32: .int32(ZigZag.decode(UInt32(truncatingIfNeeded: try reader.readVarint())))
            case .sint64: .int64(ZigZag.decode(try reader.readVarint()))
            case .bool: .bool(try reader.readVarint() != 0)
            case .enum: .enumeration(Int32(truncatingIfNeeded: try reader.readVarint()))
            case .fixed32: .uint32(try reader.readFixed32())
            case .sfixed32: .int32(Int32(bitPattern: try reader.readFixed32()))
            case .float: .float(Float(bitPattern: try reader.readFixed32()))
            case .fixed64: .uint64(try reader.readFixed64())
            case .sfixed64: .int64(Int64(bitPattern: try reader.readFixed64()))
            case .double: .double(Double(bitPattern: try reader.readFixed64()))
            case .string: try string(from: &reader, validatingUTF8: validatingUTF8, bytes: bytes)
            case .bytes, .message, .group: .bytes(try reader.readBytes())
        }
    }

    private static func string(
        from reader: inout WireReader, validatingUTF8: Bool, bytes: [UInt8]
    ) throws(WireError) -> DynamicValue {
        if validatingUTF8 { return .string(try reader.readString()) }
        let range = try reader.readPayloadRange()
        if let text = try? WireReader.string(from: bytes, in: range) { return .string(text) }
        return .bytes(Array(bytes[range]))
    }
}
