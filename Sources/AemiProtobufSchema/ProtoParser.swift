/// Parses the currently supported subset of proto declarations, rejecting unsupported tokens.
/// Imports, options, oneofs, maps, editions, and type-name resolution are not yet supported.
public struct ProtoParser: Sendable {
    /// Maximum simultaneously open message declarations.
    public let maxDepth: Int
    /// Maximum UTF-8 source bytes accepted before allocating lexer storage.
    public let maxSourceBytes: Int

    /// Creates a parser with nonnegative source-size and nesting bounds.
    public init(maxDepth: Int = 100, maxSourceBytes: Int = 16 * 1_024 * 1_024) {
        self.maxDepth = max(0, maxDepth)
        self.maxSourceBytes = max(0, maxSourceBytes)
    }

    /// Parses a bounded source, or throws when it is malformed or outside the supported grammar.
    /// Unresolved names remain message type names in the result.
    /// - Throws: `ProtoParseError` for invalid syntax, unsupported tokens, or exceeded limits.
    /// - Complexity: O(source scalars) time and storage, with at most `maxDepth` open messages.
    public func parse(_ text: String, name: String = "input.proto") throws(ProtoParseError) -> FileDescriptor {
        guard text.utf8.count <= maxSourceBytes else { throw ProtoParseError("Source byte limit exceeded") }
        var lexer = ProtoLexer(text)
        var file = FileDescriptor(name: name)

        var tok = lexer.nextToken()
        while tok != .eof {
            switch tok {
                case .syntax:
                    guard lexer.nextToken() == .equal else { throw ProtoParseError("Expected '=' after syntax") }
                    guard case .stringLiteral(let s) = lexer.nextToken() else {
                        throw ProtoParseError("Expected string literal for syntax")
                    }
                    guard s == "proto2" || s == "proto3" else { throw ProtoParseError("Unsupported syntax \(s)") }
                    file.syntax = s
                    guard lexer.nextToken() == .semicolon else { throw ProtoParseError("Expected ';' after syntax") }
                case .package:
                    guard case .identifier(let pkg) = lexer.nextToken() else {
                        throw ProtoParseError("Expected package name")
                    }
                    file.package = pkg
                    guard lexer.nextToken() == .semicolon else { throw ProtoParseError("Expected ';' after package") }
                case .message:
                    let msg = try parseMessageBody(&lexer, syntax: file.syntax)
                    file.messages.append(msg)
                case .enum:
                    let e = try parseEnum(&lexer)
                    file.enums.append(e)
                case .semicolon: break
                case .invalid(let reason): throw ProtoParseError(reason)
                default: throw ProtoParseError("Unsupported declaration")
            }
            tok = lexer.nextToken()
        }
        return file
    }

    /// One open message and the oneof being filled inside it, if any.
    private struct Frame {
        var message: MessageDescriptor
        var openOneof: Int32?
    }

    // Iterative stack-based parser to avoid recursion (ADR-0006)
    private func parseMessageBody(_ lexer: inout ProtoLexer, syntax: String) throws(ProtoParseError)
        -> MessageDescriptor
    {
        let rootName = try lexer.declarationName("message")
        guard maxDepth > 0 else { throw ProtoParseError("Message nesting limit exceeded") }
        var stack = [Frame(message: MessageDescriptor(name: rootName))]
        let proto3 = syntax == "proto3"

        while var frame = stack.popLast() {
            let tok = lexer.nextToken()
            defer { if tok != .closeBrace, tok != .message { stack.append(frame) } }
            switch tok {
                case .message:
                    guard frame.openOneof == nil else { throw ProtoParseError("Message inside oneof") }
                    let name = try lexer.declarationName("message")
                    guard stack.count + 1 < maxDepth else { throw ProtoParseError("Message nesting limit exceeded") }
                    stack.append(frame)
                    stack.append(Frame(message: MessageDescriptor(name: name)))
                case .closeBrace:
                    if let open = frame.openOneof {
                        guard frame.message.fields.contains(where: { $0.oneofIndex == open }) else {
                            throw ProtoParseError("Empty oneof \(frame.message.oneofs[Int(open)].name)")
                        }
                        frame.openOneof = nil
                        stack.append(frame)
                        continue
                    }
                    var finished = frame.message
                    finished.addSyntheticOneofs()
                    guard let parentIndex = stack.indices.last else { return finished }
                    stack[parentIndex].message.nestedMessages.append(finished)
                case .enum:
                    guard frame.openOneof == nil else { throw ProtoParseError("Enum inside oneof") }
                    frame.message.nestedEnums.append(try parseEnum(&lexer))
                case .oneof:
                    guard frame.openOneof == nil else { throw ProtoParseError("Nested oneof") }
                    let name = try lexer.declarationName("oneof")
                    frame.openOneof = Int32(frame.message.oneofs.count)
                    frame.message.oneofs.append(OneofDescriptor(name: name))
                case .repeated, .optional, .required:
                    guard frame.openOneof == nil else { throw ProtoParseError("Label inside oneof") }
                    let label: FieldLabel = tok == .repeated ? .repeated : (tok == .required ? .required : .optional)
                    var field = try parseField(&lexer, label: label)
                    field.proto3Optional = tok == .optional && proto3
                    frame.message.fields.append(field)
                case .identifier(let typeName):
                    var field = try parseFieldRest(&lexer, typeName: typeName, label: .optional)
                    field.oneofIndex = frame.openOneof
                    frame.message.fields.append(field)
                case .eof:
                    throw ProtoParseError("Unexpected EOF inside message")
                case .semicolon: break
                case .invalid(let reason): throw ProtoParseError(reason)
                default: throw ProtoParseError("Unsupported message declaration")
            }
        }
        throw ProtoParseError("Empty message stack")
    }

    private func parseField(_ lexer: inout ProtoLexer, label: FieldLabel) throws(ProtoParseError) -> FieldDescriptor {
        let typeName = try lexer.requireIdentifier("field type name")
        return try parseFieldRest(&lexer, typeName: typeName, label: label)
    }

    private func parseFieldRest(
        _ lexer: inout ProtoLexer, typeName: String, label: FieldLabel
    ) throws(ProtoParseError) -> FieldDescriptor {
        let fname = try lexer.requireIdentifier("field name")
        try lexer.expect(.equal, "'=' for field \(fname)")
        guard case .intLiteral(let fnum) = lexer.nextToken() else {
            throw ProtoParseError("Expected field number for field \(fname)")
        }
        guard fnum > 0, fnum <= 536_870_911, !(19_000 ... 19_999).contains(fnum) else {
            throw ProtoParseError("Invalid field number for field \(fname)")
        }
        try lexer.expect(.semicolon, "';' after field \(fname)")

        let type = resolveType(typeName)
        let resolvedTypeName = (type == .message || type == .enum) ? typeName : ""
        return FieldDescriptor(
            name: fname, number: fnum, label: label,
            type: type, typeName: resolvedTypeName, jsonName: Self.jsonName(for: fname))
    }

    private func parseEnum(_ lexer: inout ProtoLexer) throws(ProtoParseError) -> EnumDescriptor {
        let name = try lexer.declarationName("enum")

        var enumDesc = EnumDescriptor(name: name)
        var tok = lexer.nextToken()
        while tok != .closeBrace && tok != .eof {
            if case .identifier(let vname) = tok {
                try lexer.expect(.equal, "'=' for enum value \(vname)")
                guard case .intLiteral(let vnum) = lexer.nextToken() else {
                    throw ProtoParseError("Expected number for enum value \(vname)")
                }
                try lexer.expect(.semicolon, "';' after enum value \(vname)")
                enumDesc.values.append(EnumValueDescriptor(name: vname, number: vnum))
            } else if tok != .semicolon {
                throw ProtoParseError("Unsupported enum declaration")
            }
            tok = lexer.nextToken()
        }
        guard tok == .closeBrace else { throw ProtoParseError("Unexpected EOF inside enum") }
        return enumDesc
    }

    private func resolveType(_ name: String) -> FieldType {
        switch name {
            case "double": return .double
            case "float": return .float
            case "int64": return .int64
            case "uint64": return .uint64
            case "int32": return .int32
            case "fixed64": return .fixed64
            case "fixed32": return .fixed32
            case "bool": return .bool
            case "string": return .string
            case "bytes": return .bytes
            case "uint32": return .uint32
            case "sfixed32": return .sfixed32
            case "sfixed64": return .sfixed64
            case "sint32": return .sint32
            case "sint64": return .sint64
            default: return .message
        }
    }

    /// protoc's `ToJsonName`: underscores vanish and capitalise the next character.
    static func jsonName(for name: String) -> String {
        var result = ""
        var capitalizeNext = false
        for character in name {
            if character == "_" {
                capitalizeNext = true
            } else if capitalizeNext {
                result += character.uppercased()
                capitalizeNext = false
            } else {
                result.append(character)
            }
        }
        return result
    }
}
