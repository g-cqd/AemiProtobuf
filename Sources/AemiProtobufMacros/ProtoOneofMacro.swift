import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@ProtoOneof`: the `oneof` conformance of an enumeration whose cases are its members.
struct ProtoOneofMacro: ExtensionMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let decl = declaration.as(EnumDeclSyntax.self) else {
            ProtoFieldParser.error(
                node, "@ProtoOneof applies to an enumeration; mark the message property holding it @ProtoOneofField",
                in: context)
            return []
        }
        guard let members = members(of: decl, in: context) else { return [] }
        let access = ProtoExtension.access(decl.modifiers)
        return [
            try ProtoExtension.make(
                type, inheritance: decl.inheritanceClause, wanted: ["AemiProtoOneof", "Codable"],
                members: [access + encode(members), access + decode(members)])
        ]
    }

    /// The cases, each `@ProtoField(number)` with one associated value; `nil` after an error diagnostic.
    private static func members(of decl: EnumDeclSyntax, in context: some MacroExpansionContext) -> [ProtoFieldSpec]? {
        var specs: [ProtoFieldSpec] = []
        var seen: [Int: String] = [:]
        var failed = false
        for member in decl.memberBlock.members {
            guard let cases = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
            guard let spec = self.member(cases, in: context) else {
                failed = true
                continue
            }
            if let first = ProtoExtension.isTaken(spec.number, by: spec.name, in: &seen) {
                ProtoFieldParser.error(
                    cases, "field number \(spec.number) is used by '\(first)' and '\(spec.name)'", in: context)
                failed = true
            }
            specs.append(spec)
        }
        return failed ? nil : specs
    }

    private static func member(_ cases: EnumCaseDeclSyntax, in context: some MacroExpansionContext) -> ProtoFieldSpec? {
        guard cases.elements.count == 1, let element = cases.elements.first else {
            ProtoFieldParser.error(
                cases, "a oneof member is one case per declaration, with its own @ProtoField", in: context)
            return nil
        }
        let name = element.name.text
        let attribute = cases.attributes.lazy
            .compactMap { element -> AttributeSyntax? in
                if case .attribute(let attribute) = element, attribute.attributeName.trimmedDescription == "ProtoField"
                {
                    return attribute
                }
                return nil
            }
            .first
        guard let attribute else {
            ProtoFieldParser.error(cases, "'\(name)' needs @ProtoField(number)", in: context)
            return nil
        }
        guard let parameters = element.parameterClause?.parameters, parameters.count == 1,
            let type = parameters.first?.type
        else {
            ProtoFieldParser.error(cases, "'\(name)' needs exactly one associated value", in: context)
            return nil
        }
        guard let arguments = ProtoFieldParser.arguments(of: attribute, in: context) else { return nil }
        let swiftType: String
        if type.trimmedDescription == "[UInt8]" {
            swiftType = "[UInt8]"
        } else {
            guard !type.is(ArrayTypeSyntax.self), !type.is(OptionalTypeSyntax.self), !type.is(DictionaryTypeSyntax.self)
            else {
                ProtoFieldParser.error(
                    cases, "'\(name)': a oneof member cannot be repeated, optional or a map", in: context)
                return nil
            }
            guard let text = ProtoFieldParser.scalarName(type, name, cases, in: context) else { return nil }
            swiftType = text
        }
        let kind = arguments.kind ?? ProtoKind.inferred(for: swiftType)
        guard ProtoFieldParser.fits(kind, swiftType, name, cases, in: context) else { return nil }
        return ProtoFieldSpec(name: name, number: arguments.number, kind: kind, shape: .single, swiftType: swiftType)
    }

    /// The member that is set, always written: a member has presence.
    private static func encode(_ members: [ProtoFieldSpec]) -> String {
        let cases = members.map { f in
            let write =
                f.kind == .message
                ? "try w.appendMessage(field: \(f.number)) { w throws(WireError) in try __v.__aepbEncode(into: &w) }"
                : "w.appendTag(\(f.number), \(f.kind.wireType))\n"
                    + ProtoFieldScalar(kind: f.kind, swiftType: f.swiftType).write("__v")
            return "case .\(f.name)(let __v):\n\(write)"
        }
        return "func __aepbEncode(into w: inout WireWriter) throws(WireError) {\nswitch self {\n"
            + cases.joined(separator: "\n") + "\n}\n}"
    }

    private static func decode(_ members: [ProtoFieldSpec]) -> String {
        let cases = members.map { f -> String in
            let head = "case (\(f.number), \(f.kind.wireType)):"
            switch f.kind {
                case .message:
                    return """
                        \(head)
                        var __m = \(f.swiftType)()
                        if case .\(f.name)(let __old)? = value { __m = __old }
                        value = nil
                        try r.readMessage { r throws(WireError) in try __m.__aepbMerge(from: &r) }
                        value = .\(f.name)(__m)
                        return true
                        """
                case .enumeration:
                    return """
                        \(head)
                        let __raw = try r.readInt32()
                        if let __v = ProtoEnumeration.value(\(f.swiftType).self, __raw) {
                        value = .\(f.name)(__v)
                        } else {
                        unknown.appendVarint(field: \(f.number), UInt64(bitPattern: Int64(__raw)))
                        }
                        return true
                        """
                default:
                    return
                        "\(head)\nvalue = .\(f.name)(\(ProtoFieldScalar(kind: f.kind, swiftType: f.swiftType).read))\nreturn true"
            }
        }
        return """
            static func __aepbDecodeField(
            _ tag: FieldTag, from r: inout WireReader, into value: inout Self?, unknown: inout UnknownFields
            ) throws(WireError) -> Bool {
            switch (tag.fieldNumber.rawValue, tag.wireType) {
            \(cases.joined(separator: "\n"))
            default: return false
            }
            }
            """
    }
}
