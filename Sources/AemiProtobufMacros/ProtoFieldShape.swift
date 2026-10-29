/// How many values a field holds.
enum ProtoFieldShape {
    /// Implicit presence: a default value is left out.
    case single
    /// Explicit presence: a set value is always written.
    case optional
    /// Zero or more values.
    case repeated
    /// A `[Key: Value]`, written as repeated entry messages (key 1, value 2); the spec's `kind` and `swiftType` are the value's.
    case map
    /// A `@ProtoOneof` property: an optional enumeration whose cases are fields; the spec's number is 0 and `swiftType` the
    /// enumeration.
    case oneof
}
