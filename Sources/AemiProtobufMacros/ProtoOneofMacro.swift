import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@ProtoOneof`: the `oneof` conformance of an enumeration.
struct ProtoOneofMacro: ExtensionMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(EnumDeclSyntax.self) else {
            ProtoFieldParser.error(
                node, "@ProtoOneof applies to an enumeration; mark the message property holding it @ProtoOneofField",
                in: context)
            return []
        }
        return [
            try ExtensionDeclSyntax(
                """
                extension \(raw: type.trimmedDescription): AemiProtoOneof, Codable {
                func __aepbEncode(into w: inout WireWriter) throws(WireError) {}
                static func __aepbDecodeField(
                _ tag: FieldTag, from r: inout WireReader, into value: inout Self?, unknown: inout UnknownFields
                ) throws(WireError) -> Bool { false }
                }
                """)
        ]
    }
}
