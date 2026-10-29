/// One field of a message, as the macro understood it from syntax.
struct ProtoFieldSpec {
    /// The property name as written, backticks included.
    let name: String
    let number: Int
    let kind: ProtoKind
    let shape: ProtoFieldShape
    /// The element type for a repeated field, the wrapped type for an optional one, the value type for a map, else the property
    /// type.
    let swiftType: String
    /// A map's key kind and Swift type.
    var key: (kind: ProtoKind, swiftType: String)? = nil
    /// A proto2 `required` field: optional in Swift, and the coders refuse a message without it.
    var required = false
    /// `false`: a repeated number written one record per element.
    var packed = true

    /// The name without backticks, as a path to a missing required field spells it.
    var plainName: String { name.filter { $0 != "`" } }
}
