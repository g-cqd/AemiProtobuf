import SwiftSyntax
import SwiftSyntaxBuilder

/// What the two macros that write conformances share: the access a witness needs, the extension they add, and the check that
/// no field number is used twice.
enum ProtoExtension {
    /// `public ` or `package ` for a type that has that access, else nothing: a witness for a public protocol must be as
    /// visible as its type.
    static func access(_ modifiers: DeclModifierListSyntax) -> String {
        for modifier in modifiers where ["public", "open", "package"].contains(modifier.name.text) {
            return modifier.name.text == "package" ? "package " : "public "
        }
        return ""
    }

    /// `extension Type: <the wanted protocols the type does not already declare> { members }`. The declared list is read from
    /// syntax, because a macro's `protocols` omits `Codable` (a typealias for two protocols).
    static func make(
        _ type: some TypeSyntaxProtocol, inheritance: InheritanceClauseSyntax?, wanted: [String], members: [String]
    ) throws -> ExtensionDeclSyntax {
        let declared = Set(inheritance?.inheritedTypes.map(\.type.trimmedDescription) ?? [])
        let missing = wanted.filter { protocolName in
            guard protocolName == "Codable" else { return !declared.contains(protocolName) }
            return !declared.contains("Codable") && !(declared.contains("Encodable") && declared.contains("Decodable"))
        }
        let conformance = missing.isEmpty ? "" : ": " + missing.joined(separator: ", ")
        return try ExtensionDeclSyntax(
            "extension \(raw: type.trimmedDescription)\(raw: conformance) {\n\(raw: members.joined(separator: "\n\n"))\n}"
        )
    }

    /// Whether `number` was already taken, recording it for `name` when it was not.
    static func isTaken(_ number: Int, by name: String, in seen: inout [Int: String]) -> String? {
        if let first = seen[number] { return first }
        seen[number] = name
        return nil
    }
}
