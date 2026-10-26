/// One field of a message, as the macro understood it from syntax.
struct ProtoFieldSpec {
    /// The property name as written, backticks included.
    let name: String
    let number: Int
    let kind: ProtoKind
    let shape: ProtoFieldShape
    /// The element type for a repeated field, the wrapped type for an optional one, else the property type.
    let swiftType: String
}
