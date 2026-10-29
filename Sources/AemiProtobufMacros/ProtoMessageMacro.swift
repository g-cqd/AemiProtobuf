import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@ProtoMessage`: makes a struct a protobuf message. It adds the fast path (`AemiProtoFastEncodable`,
/// `AemiProtoFastDecodable`) and, for the generic coders, `Codable` with integer `CodingKeys` taken from the field numbers.
struct ProtoMessageMacro: ExtensionMacro, MemberMacro {
    /// The `unknownFields` member, unless the attribute says `unknownFields: .discard` (ADR-0012).
    static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self), !discardsUnknownFields(node) else { return [] }
        let access = declaration.as(StructDeclSyntax.self).map(accessModifier) ?? ""
        return ["\(raw: access)var unknownFields = UnknownFields()"]
    }

    /// Whether the attribute is `@ProtoMessage(unknownFields: .discard)`.
    static func discardsUnknownFields(_ node: AttributeSyntax) -> Bool {
        guard case .argumentList(let list)? = node.arguments else { return false }
        return list.contains {
            $0.label?.text == "unknownFields"
                && $0.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "discard"
        }
    }

    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let decl = declaration.as(StructDeclSyntax.self) else {
            ProtoFieldParser.error(node, "@ProtoMessage only applies to a struct", in: context)
            return []
        }
        let keepsUnknown = !discardsUnknownFields(node)
        if keepsUnknown, declaresMember(named: "unknownFields", in: decl) {
            ProtoFieldParser.error(
                node,
                "'unknownFields' is the member @ProtoMessage adds; rename the property or use @ProtoMessage(unknownFields: .discard)",
                in: context)
            return []
        }
        guard let fields = ProtoFieldParser.fields(of: decl, in: context) else { return [] }
        let access = accessModifier(of: decl)
        var members = [
            ProtoMessageCodegen.encode(fields, keepsUnknown: keepsUnknown), ProtoMessageCodegen.decode,
            ProtoMessageCodegen.merge(fields, keepsUnknown: keepsUnknown)
        ]
        .map { "\(access)\($0)" }
        if !declaresCodingKeys(decl) { members.append(ProtoMessageCodegen.codingKeys(fields)) }
        // The declared list is read from syntax, because `protocols` omits `Codable` (a typealias for two protocols).
        let declared = Set(decl.inheritanceClause?.inheritedTypes.map(\.type.trimmedDescription) ?? [])
        var wanted = ["AemiProtoFastEncodable", "AemiProtoFastDecodable"].filter { !declared.contains($0) }
        if !declared.contains("Codable"), !(declared.contains("Encodable") && declared.contains("Decodable")) {
            wanted.append("Codable")
        }
        let conformance = wanted.isEmpty ? "" : ": " + wanted.joined(separator: ", ")
        return [
            try ExtensionDeclSyntax(
                "extension \(raw: type.trimmedDescription)\(raw: conformance) {\n\(raw: members.joined(separator: "\n\n"))\n}"
            )
        ]
    }

    /// `public ` or `package ` for a type that has that access, else nothing: a witness for a public protocol must be as
    /// visible as its type.
    private static func accessModifier(of decl: StructDeclSyntax) -> String {
        for modifier in decl.modifiers where ["public", "open", "package"].contains(modifier.name.text) {
            return modifier.name.text == "package" ? "package " : "public "
        }
        return ""
    }

    private static func declaresMember(named name: String, in decl: StructDeclSyntax) -> Bool {
        decl.memberBlock.members.contains { member in
            member.decl.as(VariableDeclSyntax.self)?.bindings
                .contains {
                    $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == name
                } ?? false
        }
    }

    private static func declaresCodingKeys(_ decl: StructDeclSyntax) -> Bool {
        decl.memberBlock.members.contains { member in
            if let nested = member.decl.as(EnumDeclSyntax.self) { return nested.name.text == "CodingKeys" }
            if let nested = member.decl.as(StructDeclSyntax.self) { return nested.name.text == "CodingKeys" }
            return false
        }
    }
}
