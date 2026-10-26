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
                if let first = seen[spec.number] {
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
        guard let (number, requested) = arguments(of: attribute, in: context) else { return nil }
        guard let (shape, swiftType) = shapeAndType(of: type, name, binding, in: context) else { return nil }
        let kind = requested ?? ProtoKind.inferred(for: swiftType)
        if let allowed = kind.swiftTypes, !allowed.contains(swiftType) {
            error(
                binding,
                "'\(name)' is \(swiftType), which cannot be a protobuf \(kind.rawValue); use \(allowed.sorted().joined(separator: ", "))",
                in: context)
            return nil
        }
        return ProtoFieldSpec(name: name, number: number, kind: kind, shape: shape, swiftType: swiftType)
    }

    private static func fieldAttribute(of variable: VariableDeclSyntax) -> AttributeSyntax? {
        for element in variable.attributes {
            if case .attribute(let attribute) = element, attribute.attributeName.trimmedDescription == "ProtoField" {
                return attribute
            }
        }
        return nil
    }

    private static func arguments(
        of attribute: AttributeSyntax, in context: some MacroExpansionContext
    ) -> (Int, ProtoKind?)? {
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
        guard list.count > 1 else { return (number, nil) }
        let second = list[list.index(after: list.startIndex)].expression
        guard let name = second.as(MemberAccessExprSyntax.self)?.declName.baseName.text else {
            error(attribute, "the kind of @ProtoField must be a case such as .sint32", in: context)
            return nil
        }
        if name == "automatic" { return (number, nil) }
        guard let kind = ProtoKind(rawValue: name) else {
            error(attribute, "unknown protobuf kind '.\(name)'", in: context)
            return nil
        }
        return (number, kind)
    }

    private static func isArray(_ type: TypeSyntax) -> Bool {
        type.is(ArrayTypeSyntax.self)
    }

    private static func shapeAndType(
        of type: TypeSyntax, _ name: String, _ node: some SyntaxProtocol, in context: some MacroExpansionContext
    ) -> (ProtoFieldShape, String)? {
        if let optional = type.as(OptionalTypeSyntax.self) {
            let wrapped = optional.wrappedType
            guard !wrapped.is(ArrayTypeSyntax.self), !wrapped.is(OptionalTypeSyntax.self) else {
                error(node, "'\(name)': an optional array or optional optional has no protobuf form", in: context)
                return nil
            }
            guard let text = scalarName(wrapped, name, node, in: context) else { return nil }
            return (.optional, text)
        }
        if let array = type.as(ArrayTypeSyntax.self) {
            let element = array.element
            if element.trimmedDescription == "UInt8" { return (.single, "[UInt8]") }
            guard !element.is(ArrayTypeSyntax.self), !element.is(OptionalTypeSyntax.self) else {
                error(node, "'\(name)': nested arrays and arrays of optionals have no protobuf form", in: context)
                return nil
            }
            guard let text = scalarName(element, name, node, in: context) else { return nil }
            return (.repeated, text)
        }
        guard let text = scalarName(type, name, node, in: context) else { return nil }
        return (.single, text)
    }

    private static func scalarName(
        _ type: TypeSyntax, _ name: String, _ node: some SyntaxProtocol, in context: some MacroExpansionContext
    ) -> String? {
        if type.is(DictionaryTypeSyntax.self) || type.trimmedDescription.hasPrefix("Dictionary<") {
            error(node, "'\(name)': maps are not supported by @ProtoMessage yet", in: context)
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
