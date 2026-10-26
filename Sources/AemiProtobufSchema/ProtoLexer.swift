struct ProtoLexer {
    enum Token: Equatable, Sendable {
        case identifier(String)
        case stringLiteral(String)
        case intLiteral(Int32)
        case syntax
        case package
        case message
        case `enum`
        case `repeated`
        case `optional`
        case `required`
        case oneof
        case equal
        case semicolon
        case openBrace
        case closeBrace
        case eof
        case invalid(String)
    }

    private static let keywords: [String: Token] = [
        "syntax": .syntax, "package": .package, "message": .message, "enum": .enum,
        "repeated": .repeated, "optional": .optional, "required": .required, "oneof": .oneof
    ]

    mutating func requireIdentifier(_ context: String) throws(ProtoParseError) -> String {
        guard case .identifier(let name) = nextToken() else { throw ProtoParseError("Expected \(context)") }
        return name
    }

    mutating func expect(_ token: Token, _ context: String) throws(ProtoParseError) {
        guard nextToken() == token else { throw ProtoParseError("Expected \(context)") }
    }

    mutating func declarationName(_ kind: String) throws(ProtoParseError) -> String {
        let name = try requireIdentifier("\(kind) name")
        try expect(.openBrace, "'{' opening \(kind) \(name)")
        return name
    }

    private let text: [Unicode.Scalar]
    private var index: Int = 0

    init(_ text: String) {
        self.text = Array(text.unicodeScalars)
    }

    mutating func nextToken() -> Token {
        while true {
            if let error = skipWhitespaceAndComments() { return .invalid(error) }
            guard index < text.count else { return .eof }
            let c = text[index]

            if c == "=" {
                index += 1
                return .equal
            }
            if c == ";" {
                index += 1
                return .semicolon
            }
            if c == "{" {
                index += 1
                return .openBrace
            }
            if c == "}" {
                index += 1
                return .closeBrace
            }

            if c == "\"" || c == "'" {
                return readStringLiteral(delimiter: c)
            }

            if c >= "0" && c <= "9" {
                return readIntLiteral()
            }

            if (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "_" {
                let ident = readIdentifier()
                return Self.keywords[ident] ?? .identifier(ident)
            }

            index += 1
            return .invalid("Unsupported character at scalar \(index - 1)")
        }
    }

    private mutating func skipWhitespaceAndComments() -> String? {
        while index < text.count {
            let c = text[index]
            if c == " " || c == "\t" || c == "\n" || c == "\r" {
                index += 1
                continue
            }
            if c == "/" && index + 1 < text.count {
                let next = text[index + 1]
                if next == "/" {
                    index += 2
                    while index < text.count && text[index] != "\n" { index += 1 }
                    continue
                }
                if next == "*" {
                    index += 2
                    while index + 1 < text.count && !(text[index] == "*" && text[index + 1] == "/") {
                        index += 1
                    }
                    guard index + 1 < text.count else {
                        index = text.count
                        return "Unterminated block comment"
                    }
                    index += 2
                    continue
                }
            }
            break
        }
        return nil
    }

    private mutating func readStringLiteral(delimiter: Unicode.Scalar) -> Token {
        index += 1
        var result = ""
        while index < text.count && text[index] != delimiter {
            guard text[index] != "\\", text[index] != "\n", text[index] != "\r" else {
                return .invalid("Unsupported escape or newline in string literal")
            }
            result.unicodeScalars.append(text[index])
            index += 1
        }
        guard index < text.count else { return .invalid("Unterminated string literal") }
        index += 1
        return .stringLiteral(result)
    }

    private mutating func readIntLiteral() -> Token {
        var num: Int32 = 0
        while index < text.count && text[index] >= "0" && text[index] <= "9" {
            let digit = Int32(text[index].value - 0x30)
            guard num <= (Int32.max - digit) / 10 else {
                return .invalid("Integer literal exceeds Int32.max")
            }
            num = num * 10 + digit
            index += 1
        }
        return .intLiteral(num)
    }

    private mutating func readIdentifier() -> String {
        var ident = ""
        while index < text.count {
            let c = text[index]
            guard
                (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9") || c == "_"
                    || c == "."
            else {
                break
            }
            ident.unicodeScalars.append(c)
            index += 1
        }
        return ident
    }
}
