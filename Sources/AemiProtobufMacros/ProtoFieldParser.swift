import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Reads the stored properties of a struct into ``ProtoFieldSpec``s, and diagnoses everything the macro cannot express.
/// Matching is on the type as written: a typealias or a qualified name (`Swift.Int`) is read as a message type.
enum ProtoFieldParser {
    static let reservedNumbers = 19_000 ... 19_999

    /// - Returns: the fields in declaration order, or `nil` after an error diagnostic.
    static func fields(of decl: StructDeclSyntax, in context: some MacroExpansionContext) -> [ProtoFieldSpec]? {
        var specs: [ProtoFieldSpec] = []
        var failed = false
        var seen: [Int: String] = [:]
        for member in decl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self), isStored(variable) else { continue }
            for binding in variable.bindings where !isComputed(binding) {
                guard let spec = field(binding, variable, in: context) else {
                    failed = true
                    continue
                }
                if spec.shape != .oneof, let first = seen[spec.number] {
                    error(binding, "field number \(spec.number) is used by '\(first)' and '\(spec.name)'", in: context)
                    failed = true
                }
                seen[spec.number] = spec.name
                specs.append(spec)
            }
        }
        return failed ? nil : specs
    }

    private static func isStored(_ variable: VariableDeclSyntax) -> Bool {
        let modifiers = variable.modifiers.map(\.name.text)
        return !modifiers.contains("static") && !modifiers.contains("class") && !modifiers.contains("lazy")
    }

    private static func isComputed(_ binding: PatternBindingSyntax) -> Bool {
        guard let block = binding.accessorBlock else { return false }
        switch block.accessors {
            case .getter: return true
            case .accessors(let list):
                return list.contains { ["get", "set", "_read", "_modify"].contains($0.accessorSpecifier.text) }
        }
    }

    private static func field(
        _ binding: PatternBindingSyntax, _ variable: VariableDeclSyntax, in context: some MacroExpansionContext
    ) -> ProtoFieldSpec? {
        guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            error(binding, "a protobuf field needs a plain property name", in: context)
            return nil
        }
        if hasAttribute("ProtoOneofField", variable) { return oneofField(binding, name, in: context) }
        guard let attribute = fieldAttribute(of: variable) else {
            error(binding, "'\(name)' needs @ProtoField(number)", in: context)
            return nil
        }
        guard let type = binding.typeAnnotation?.type else {
            error(binding, "'\(name)' needs an explicit type", in: context)
            return nil
        }
        guard binding.initializer != nil || type.is(OptionalTypeSyntax.self) || isArray(type) else {
            error(binding, "'\(name)' needs a default value: the generated decoder starts from Self()", in: context)
            return nil
        }
        guard let arguments = arguments(of: attribute, in: context) else { return nil }
        if let dictionary = type.as(DictionaryTypeSyntax.self) {
            return mapField(dictionary, name, arguments, binding, in: context)
        }
        guard arguments.key == nil, arguments.value == nil else {
            error(binding, "'\(name)': key: and value: are for a map ([Key: Value]) property", in: context)
            return nil
        }
        guard let (shape, swiftType) = shapeAndType(of: type, name, binding, in: context) else { return nil }
        let kind = arguments.kind ?? ProtoKind.inferred(for: swiftType)
        guard fits(kind, swiftType, name, binding, in: context) else { return nil }
        return ProtoFieldSpec(name: name, number: arguments.number, kind: kind, shape: shape, swiftType: swiftType)
    }

    /// The kinds a map key may have: every integer, `bool` and `string`.
    static let mapKeyKinds: Set<ProtoKind> = [
        .int32, .int64, .uint32, .uint64, .sint32, .sint64, .fixed32, .fixed64, .sfixed32, .sfixed64, .bool, .string
    ]

    private static func mapField(
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
        guard fits(keyKind, keyType, name, node, in: context), fits(valueKind, valueType, name, node, in: context)
        else {
            return nil
        }
        return ProtoFieldSpec(
            name: name, number: arguments.number, kind: valueKind, shape: .map, swiftType: valueType,
            key: (keyKind, keyType))
    }

    private static func fits(
        _ kind: ProtoKind, _ swiftType: String, _ name: String, _ node: some SyntaxProtocol,
        in context: some MacroExpansionContext
    ) -> Bool {
        guard let allowed = kind.swiftTypes, !allowed.contains(swiftType) else { return true }
        error(
            node,
            "'\(name)' is \(swiftType), which cannot be a protobuf \(kind.rawValue); use \(allowed.sorted().joined(separator: ", "))",
            in: context)
        return false
    }

    private static func hasAttribute(_ name: String, _ variable: VariableDeclSyntax) -> Bool {
        variable.attributes.contains {
            if case .attribute(let attribute) = $0 { return attribute.attributeName.trimmedDescription == name }
            return false
        }
    }

    /// `@ProtoOneofField var kind: Kind? = nil`: optional, with no field number of its own.
    private static func oneofField(
        _ binding: PatternBindingSyntax, _ name: String, in context: some MacroExpansionContext
    ) -> ProtoFieldSpec? {
        guard let optional = binding.typeAnnotation?.type.as(OptionalTypeSyntax.self),
            optional.wrappedType.is(IdentifierTypeSyntax.self) || optional.wrappedType.is(MemberTypeSyntax.self)
        else {
            error(binding, "'\(name)': a @ProtoOneofField property is an optional @ProtoOneof enumeration", in: context)
            return nil
        }
        return ProtoFieldSpec(
            name: name, number: 0, kind: .message, shape: .oneof, swiftType: optional.wrappedType.trimmedDescription)
    }

    private static func fieldAttribute(of variable: VariableDeclSyntax) -> AttributeSyntax? {
        for element in variable.attributes {
            if case .attribute(let attribute) = element, attribute.attributeName.trimmedDescription == "ProtoField" {
                return attribute
            }
        }
        return nil
    }

    struct Arguments {
        var number: Int
        var kind: ProtoKind?
        var key: ProtoKind?
        var value: ProtoKind?
    }

    private static func arguments(of attribute: AttributeSyntax, in context: some MacroExpansionContext) -> Arguments? {
        guard case .argumentList(let list)? = attribute.arguments, let first = list.first,
            let literal = first.expression.as(IntegerLiteralExprSyntax.self), let number = Int(literal.literal.text)
        else {
            error(attribute, "@ProtoField needs an integer literal field number", in: context)
            return nil
        }
        guard (1 ... 536_870_911).contains(number), !reservedNumbers.contains(number) else {
            error(
                attribute, "field number \(number) is outside 1...536870911 or in the reserved 19000...19999",
                in: context)
            return nil
        }
        var result = Arguments(number: number)
        for argument in list.dropFirst() {
            guard let name = argument.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text else {
                error(attribute, "the kind of @ProtoField must be a case such as .sint32", in: context)
                return nil
            }
            var kind: ProtoKind?
            if name != "automatic" {
                guard let named = ProtoKind(rawValue: name) else {
                    error(attribute, "unknown protobuf kind '.\(name)'", in: context)
                    return nil
                }
                kind = named
            }
            switch argument.label?.text {
                case "key": result.key = kind
                case "value": result.value = kind
                default: result.kind = kind
            }
        }
        return result
    }

    private static func isArray(_ type: TypeSyntax) -> Bool {
        type.is(ArrayTypeSyntax.self)
    }

    private static func shapeAndType(
        of type: TypeSyntax, _ name: String, _ node: some SyntaxProtocol, in context: some MacroExpansionContext
    ) -> (ProtoFieldShape, String)? {
        let inner: (type: TypeSyntax, shape: ProtoFieldShape, refusal: String)
        if let optional = type.as(OptionalTypeSyntax.self) {
            inner = (optional.wrappedType, .optional, "an optional array or optional optional has no protobuf form")
        } else if let array = type.as(ArrayTypeSyntax.self) {
            if array.element.trimmedDescription == "UInt8" { return (.single, "[UInt8]") }
            inner = (array.element, .repeated, "nested arrays and arrays of optionals have no protobuf form")
        } else {
            guard let text = scalarName(type, name, node, in: context) else { return nil }
            return (.single, text)
        }
        guard !inner.type.is(ArrayTypeSyntax.self), !inner.type.is(OptionalTypeSyntax.self) else {
            error(node, "'\(name)': \(inner.refusal)", in: context)
            return nil
        }
        guard let text = scalarName(inner.type, name, node, in: context) else { return nil }
        return (inner.shape, text)
    }

    private static func scalarName(
        _ type: TypeSyntax, _ name: String, _ node: some SyntaxProtocol, in context: some MacroExpansionContext
    ) -> String? {
        if type.is(DictionaryTypeSyntax.self) || type.trimmedDescription.hasPrefix("Dictionary<") {
            error(node, "'\(name)': a map must be written [Key: Value], at the top of the property's type", in: context)
            return nil
        }
        guard type.is(IdentifierTypeSyntax.self) || type.is(MemberTypeSyntax.self) else {
            error(node, "'\(name)': unsupported type '\(type.trimmedDescription)'", in: context)
            return nil
        }
        return type.trimmedDescription
    }

    static func error(_ node: some SyntaxProtocol, _ text: String, in context: some MacroExpansionContext) {
        context.diagnose(Diagnostic(node: Syntax(node), message: MacroExpansionErrorMessage(text)))
    }
}
