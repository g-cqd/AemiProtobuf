import SwiftSyntax
import SwiftSyntaxMacros

/// The fields of a `[Key: Value]` property.
extension ProtoFieldParser {
    /// The kinds a map key may have: every integer, `bool` and `string`.
    static let mapKeyKinds: Set<ProtoKind> = [
        .int32, .int64, .uint32, .uint64, .sint32, .sint64, .fixed32, .fixed64, .sfixed32, .sfixed64, .bool, .string
    ]

    static func mapField(
        _ dictionary: DictionaryTypeSyntax, _ name: String, _ arguments: Arguments, _ node: some SyntaxProtocol,
        in context: some MacroExpansionContext
    ) -> ProtoFieldSpec? {
        guard arguments.kind == nil else {
            error(node, "'\(name)' is a map: give its kinds as key: and value:", in: context)
            return nil
        }
        guard let keyType = scalarName(dictionary.key, name, node, in: context),
            let valueType = scalarName(dictionary.value, name, node, in: context)
        else { return nil }
        let keyKind = arguments.key ?? ProtoKind.inferred(for: keyType)
        guard mapKeyKinds.contains(keyKind) else {
            error(node, "'\(name)': a map key cannot be a protobuf \(keyKind.rawValue)", in: context)
            return nil
        }
        let valueKind = arguments.value ?? ProtoKind.inferred(for: valueType)
        guard valueKind != .group, !arguments.required else {
            error(node, "'\(name)': a map value cannot be a group, and a map cannot be required", in: context)
            return nil
        }
        guard fits(keyKind, keyType, name, node, in: context), fits(valueKind, valueType, name, node, in: context)
        else {
            return nil
        }
        return ProtoFieldSpec(
            name: name, number: arguments.number, kind: valueKind, shape: .map, swiftType: valueType,
            key: (keyKind, keyType))
    }
}
