import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@ProtoMessage`: makes a struct a protobuf message. It adds the fast path (`AemiProtoFastEncodable`,
/// `AemiProtoFastDecodable`) and, for the generic coders, `Codable` with integer `CodingKeys` taken from the field numbers.
struct ProtoMessageMacro: ExtensionMacro {
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
        guard let fields = ProtoFieldParser.fields(of: decl, in: context) else { return [] }
        let access = accessModifier(of: decl)
        var members = [ProtoMessageCodegen.encode(fields), ProtoMessageCodegen.decode(fields)].map { "\(access)\($0)" }
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

    private static func declaresCodingKeys(_ decl: StructDeclSyntax) -> Bool {
        decl.memberBlock.members.contains { member in
            if let nested = member.decl.as(EnumDeclSyntax.self) { return nested.name.text == "CodingKeys" }
            if let nested = member.decl.as(StructDeclSyntax.self) { return nested.name.text == "CodingKeys" }
            return false
        }
    }
}
