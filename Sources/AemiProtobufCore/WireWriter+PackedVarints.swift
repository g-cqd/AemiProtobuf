extension WireWriter {
    /// Writes a packed `repeated int64`/`sint64` field as one record. Writes nothing for an empty array.
    /// - Complexity: O(values.count), two passes and no shift.
    public mutating func appendPackedVarints(field: FieldNumber, _ values: [Int64], _ encoding: VarintEncoding = .plain)
    {
        switch encoding {
            case .plain: packedVarints(field, values.count) { UInt64(bitPattern: values[$0]) }
            case .zigzag: packedVarints(field, values.count) { ZigZag.encode(values[$0]) }
        }
    }

    /// Writes a packed `repeated int32`/`sint32` field. A plain negative value takes ten bytes, as `int32` requires.
    public mutating func appendPackedVarints(field: FieldNumber, _ values: [Int32], _ encoding: VarintEncoding = .plain)
    {
        switch encoding {
            case .plain: packedVarints(field, values.count) { UInt64(bitPattern: Int64(values[$0])) }
            case .zigzag: packedVarints(field, values.count) { UInt64(ZigZag.encode(values[$0])) }
        }
    }

    /// Writes a packed `repeated uint64` field.
    public mutating func appendPackedVarints(field: FieldNumber, _ values: [UInt64]) {
        packedVarints(field, values.count) { values[$0] }
    }

    /// Writes a packed `repeated uint32` field.
    public mutating func appendPackedVarints(field: FieldNumber, _ values: [UInt32]) {
        packedVarints(field, values.count) { UInt64(values[$0]) }
    }

    /// The payload size is summed first, so the length prefix is exact and the body is written once, with no shift.
    @inline(__always)
    private mutating func packedVarints(_ field: FieldNumber, _ count: Int, _ element: (Int) -> UInt64) {
        guard count > 0 else { return }
        var size = 0
        for index in 0 ..< count { size += Self.varintWidth(element(index)) }
        reserve(additional: size + 11)
        appendTag(field, .lengthDelimited)
        appendVarint(UInt64(size))
        for index in 0 ..< count { appendVarintBytes(element(index)) }
    }

    @inline(__always)
    private mutating func appendVarintBytes(_ value: UInt64) {
        var rest = value
        while rest >= 0x80 {
            bytes.append(UInt8(truncatingIfNeeded: rest) | 0x80)
            rest >>= 7
        }
        bytes.append(UInt8(truncatingIfNeeded: rest))
    }
}
