extension WireReader {
    /// Reads a packed `repeated int64`/`sint64` field: the length prefix, then the varints, into one array sized from the
    /// payload before the first element is read.
    /// - Throws: the errors of ``readVarint()`` and ``readPayloadRange()``.
    /// - Complexity: O(payload bytes), one allocation.
    public mutating func readPackedVarints(_ type: Int64.Type, _ encoding: VarintEncoding = .plain) throws(WireError)
        -> [Int64]
    {
        switch encoding {
            case .plain: try packedVarints { Int64(bitPattern: $0) }
            case .zigzag: try packedVarints { ZigZag.decode($0) }
        }
    }

    /// Reads a packed `repeated int32`/`sint32` field. A plain value keeps the low 32 bits, as the reference implementations do.
    public mutating func readPackedVarints(_ type: Int32.Type, _ encoding: VarintEncoding = .plain) throws(WireError)
        -> [Int32]
    {
        switch encoding {
            case .plain: try packedVarints { Int32(truncatingIfNeeded: $0) }
            case .zigzag: try packedVarints { ZigZag.decode(UInt32(truncatingIfNeeded: $0)) }
        }
    }

    /// Reads a packed `repeated uint64` field.
    public mutating func readPackedVarints(_ type: UInt64.Type) throws(WireError) -> [UInt64] {
        try packedVarints { $0 }
    }

    /// Reads a packed `repeated uint32` field, keeping the low 32 bits.
    public mutating func readPackedVarints(_ type: UInt32.Type) throws(WireError) -> [UInt32] {
        try packedVarints { UInt32(truncatingIfNeeded: $0) }
    }

    @inline(__always)
    private mutating func packedVarints<T>(_ convert: (UInt64) -> T) throws(WireError) -> [T] {
        let range = try takePayload()
        var scoped = unsafe WireReader(
            buffer: buffer, offset: range.lowerBound, end: range.upperBound, depth: depth, limits: limits)
        var out: [T] = []
        out.reserveCapacity(scoped.remainingVarintCount)
        while !scoped.isAtEnd { out.append(convert(try scoped.readVarint())) }
        return out
    }
}
