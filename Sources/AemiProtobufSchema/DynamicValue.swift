/// One value of a ``DynamicMessage`` field: a scalar, an enumeration number, a nested message, a repeated field's elements, or a
/// map's entries. The case follows the field's Swift type, not its wire encoding: `sint32`, `sfixed32` and `int32` are all
/// `.int32`; the descriptor says how to write it.
public indirect enum DynamicValue: Sendable, Hashable {
    case int32(Int32)
    case int64(Int64)
    case uint32(UInt32)
    case uint64(UInt64)
    case double(Double)
    case float(Float)
    case bool(Bool)
    case string(String)
    /// Also what a `string` field that does not check UTF-8 (proto2, or `utf8_validation = NONE`) holds when its bytes are not
    /// UTF-8, so they are written back unchanged.
    case bytes([UInt8])
    /// An enumeration's number, named or not.
    case enumeration(Int32)
    case message(DynamicMessage)
    case list([DynamicValue])
    case map([DynamicValue: DynamicValue])
}
