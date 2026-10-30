extension DynamicValue {
    /// The zero of a field type: what an implicit-presence field at its default holds, and what a map entry's absent key or value
    /// reads as.
    static func zero(of type: FieldType, typeName: String?, firstEnumValue: Int32?) -> DynamicValue {
        switch type {
            case .int32, .sint32, .sfixed32: .int32(0)
            case .int64, .sint64, .sfixed64: .int64(0)
            case .uint32, .fixed32: .uint32(0)
            case .uint64, .fixed64: .uint64(0)
            case .double: .double(0)
            case .float: .float(0)
            case .bool: .bool(false)
            case .string: .string("")
            case .bytes: .bytes([])
            case .enum: .enumeration(firstEnumValue ?? 0)
            case .message, .group: .message(DynamicMessage(typeName: typeName ?? ""))
        }
    }

    /// Whether an implicit-presence field holding this value is left out: zero, `false`, empty. A negative zero is written.
    var isImplicitDefault: Bool {
        switch self {
            case .int32(let value), .enumeration(let value): value == 0
            case .int64(let value): value == 0
            case .uint32(let value): value == 0
            case .uint64(let value): value == 0
            case .double(let value): value.bitPattern == 0
            case .float(let value): value.bitPattern == 0
            case .bool(let value): !value
            case .string(let value): value.isEmpty
            case .bytes(let value): value.isEmpty
            case .message, .list, .map: false
        }
    }
}
