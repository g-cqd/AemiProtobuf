extension ProtoMessageView {
    public func uint64(_ field: FieldNumber) -> UInt64? { last(field, .varint)?.value }
    public func int64(_ field: FieldNumber) -> Int64? { uint64(field).map { Int64(bitPattern: $0) } }
    public func uint32(_ field: FieldNumber) -> UInt32? { uint64(field).map { UInt32(truncatingIfNeeded: $0) } }
    /// An `int32` or an enumeration's number.
    public func int32(_ field: FieldNumber) -> Int32? { uint64(field).map { Int32(truncatingIfNeeded: $0) } }
    public func bool(_ field: FieldNumber) -> Bool? { uint64(field).map { $0 != 0 } }
    public func sint32(_ field: FieldNumber) -> Int32? {
        uint64(field).map { ZigZag.decode(UInt32(truncatingIfNeeded: $0)) }
    }
    public func sint64(_ field: FieldNumber) -> Int64? { uint64(field).map { ZigZag.decode($0) } }
    public func fixed32(_ field: FieldNumber) -> UInt32? {
        last(field, .fixed32).map { UInt32(truncatingIfNeeded: $0.value) }
    }
    public func sfixed32(_ field: FieldNumber) -> Int32? { fixed32(field).map { Int32(bitPattern: $0) } }
    public func float(_ field: FieldNumber) -> Float? { fixed32(field).map { Float(bitPattern: $0) } }
    public func fixed64(_ field: FieldNumber) -> UInt64? { last(field, .fixed64)?.value }
    public func sfixed64(_ field: FieldNumber) -> Int64? { fixed64(field).map { Int64(bitPattern: $0) } }
    public func double(_ field: FieldNumber) -> Double? { fixed64(field).map { Double(bitPattern: $0) } }

    /// Every varint of a repeated field, packed runs and single occurrences alike, in order.
    /// - Throws: ``WireError/malformedVarint(at:)`` or ``WireError/truncated(at:)`` for a packed run that is not varints.
    public func varints(_ field: FieldNumber) throws(WireError) -> [UInt64] {
        var values: [UInt64] = []
        for entry in entries where entry.number == field.rawValue {
            switch entry.wireType {
                case .varint: values.append(entry.value)
                case .lengthDelimited:
                    try WireReader.withReader(over: bytes, in: entry.payload, depth: depth, limits: limits) {
                        (run) throws(WireError) in
                        while !run.isAtEnd { values.append(try run.readVarint()) }
                    }
                default: continue
            }
        }
        return values
    }
}
