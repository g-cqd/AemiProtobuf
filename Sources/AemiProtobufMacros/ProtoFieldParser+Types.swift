import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// How a property's Swift type maps to a field's shape and protobuf type. Apart from ProtoFieldParser.swift
// to keep each file within the 250 lines SourceStructureTests allows.
extension ProtoFieldParser {
    static func isArray(_ type: TypeSyntax) -> Bool {
        type.is(ArrayTypeSyntax.self)
    }

    static func shapeAndType(
        of type: TypeSyntax,
        _ name: String,
        _ node: some SyntaxProtocol,
        in context: some MacroExpansionContext
    ) -> (ProtoFieldShape, String)? {
        let inner: (type: TypeSyntax, shape: ProtoFieldShape, refusal: String)
        // `[UInt8]` is bytes, a scalar: as an optional, as a repeated field's element, as a map value.
        if let optional = type.as(OptionalTypeSyntax.self), isBytes(optional.wrappedType) {
            return (.optional, "[UInt8]")
        }
        if let array = type.as(ArrayTypeSyntax.self), isBytes(array.element) { return (.repeated, "[UInt8]") }
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

    static func isBytes(_ type: TypeSyntax) -> Bool { type.trimmedDescription == "[UInt8]" }

    static func scalarName(
        _ type: TypeSyntax,
        _ name: String,
        _ node: some SyntaxProtocol,
        in context: some MacroExpansionContext
    ) -> String? {
        if type.is(DictionaryTypeSyntax.self) || type.trimmedDescription.hasPrefix("Dictionary<") {
            error(node, "'\(name)': a map must be written [Key: Value], at the top of the property's type", in: context)
            return nil
        }
        if isBytes(type) { return "[UInt8]" }
        guard type.is(IdentifierTypeSyntax.self) || type.is(MemberTypeSyntax.self) else {
            error(node, "'\(name)': unsupported type '\(type.trimmedDescription)'", in: context)
            return nil
        }
        return type.trimmedDescription
    }
}
