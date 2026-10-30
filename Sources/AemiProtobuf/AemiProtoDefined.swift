/// A type with a protobuf definition: what `@ProtoMessage` writes for a message, and what an enumeration gets by conforming
/// (roadmap 0005). ``ProtoDefinitions/file(for:package:)`` gathers definitions into a `.proto` file that `ProtoCompiler`
/// compiles to the descriptors a dynamic message, the JSON mapping or a schema check needs.
///
/// Definitions are written in edition 2023, which says exactly what the macro means: implicit presence for a plain field,
/// explicit for an optional one, `LEGACY_REQUIRED`, delimited groups, expanded `packed: false`.
public protocol AemiProtoDefined {
    /// The name the definition declares: the Swift type's own name.
    static var protoName: String { get }
    /// The declaration, `message Name { … }` or `enum Name { … }`.
    static var protoDefinition: String { get }
    /// The types the declaration refers to: messages, enumerations, oneofs.
    static var protoDependencies: [Any.Type] { get }
}

/// An enumeration of integer cases gets its definition from its cases: values named `TYPE_CASE` in upper snake case (enum
/// values share their scope, so the type's name keeps them apart), closed unless `init(rawValue:)` accepts a number with no
/// case.
extension AemiProtoDefined where Self: CaseIterable & RawRepresentable, Self.RawValue: BinaryInteger {
    public static var protoName: String { String(describing: Self.self) }

    public static var protoDefinition: String {
        let prefix = ProtoDefinitions.upperSnake(protoName)
        let numbers = allCases.map { Int64($0.rawValue) }
        let unused = (numbers.max() ?? 0) + 1
        let open = RawValue(exactly: unused).flatMap { Self(rawValue: $0) } != nil
        var lines = ["enum \(protoName) {"]
        if !open { lines.append("  option features.enum_type = CLOSED;") }
        for value in allCases {
            lines.append("  \(prefix)_\(ProtoDefinitions.upperSnake(String(describing: value))) = \(value.rawValue);")
        }
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }

    public static var protoDependencies: [Any.Type] { [] }
}
