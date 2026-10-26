import SwiftSyntax
import SwiftSyntaxMacros

/// `@ProtoField`: a marker. `@ProtoMessage` reads it from the property's attributes; this expansion adds nothing.
struct ProtoFieldMacro: PeerMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}
