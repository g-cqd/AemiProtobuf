/// The protobuf type a `@ProtoField` is written as, when the Swift type alone does not say. `.automatic` reads it from the
/// Swift type: `Int`/`Int64` are `int64`, `Int32` is `int32`, `UInt32` is `uint32`, `UInt`/`UInt64` are `uint64`, and so on;
/// any other type is a message. Only `sint*`, `fixed*`, `sfixed*` and `enumeration` need naming.
public enum ProtoKind: Sendable {
    case automatic
    case int32, int64, uint32, uint64, sint32, sint64, fixed32, fixed64, sfixed32, sfixed64
    case bool, float, double, string, bytes, message
    /// A Swift enum with an `Int32` raw value, written as a varint.
    case enumeration
}
