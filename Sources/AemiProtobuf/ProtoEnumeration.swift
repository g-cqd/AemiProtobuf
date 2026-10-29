/// The generated code's access to an enumeration field's cases.
///
/// An enumeration whose `init(rawValue:)` can fail is closed, as proto2's are: a number with no case goes to the unknown fields.
/// One whose `init(rawValue:)` cannot fail (a hand-written `RawRepresentable` with a case such as `unrecognized(Int32)`) is open,
/// as proto3's are: every number is a value.
public enum ProtoEnumeration {
    /// The case for `number`, or nil when a closed enumeration has none. Through the protocol, so a non-failable initializer is
    /// called the same way as a failable one.
    @inlinable
    public static func value<E: RawRepresentable>(_ type: E.Type, _ number: Int32) -> E? where E.RawValue == Int32 {
        E(rawValue: number)
    }
}
