/// A cursor over a file's tokens, with the small readers the grammar is made of.
struct ProtoTokenStream {
    let tokens: [ProtoToken]
    let file: String
    private(set) var position = 0

    init(_ tokens: [ProtoToken], file: String) {
        self.tokens = tokens
        self.file = file
    }

    var current: ProtoToken { tokens[position] }
    var atEnd: Bool { current.kind == .end }

    func peek(_ offset: Int = 1) -> ProtoToken { tokens[min(position + offset, tokens.count - 1)] }

    @discardableResult
    mutating func take() -> ProtoToken {
        let token = tokens[position]
        if position < tokens.count - 1 { position += 1 }
        return token
    }

    func error(_ message: String, at token: ProtoToken? = nil) -> ProtoCompileError {
        let at = token ?? current
        return ProtoCompileError(file: file, line: at.line, column: at.column, message: message)
    }

    /// Takes the symbol if it is next.
    mutating func accept(_ symbol: String) -> Bool {
        guard current.isSymbol(symbol) else { return false }
        take()
        return true
    }

    mutating func expect(_ symbol: String) throws(ProtoCompileError) {
        guard accept(symbol) else { throw error("expected \"\(symbol)\"") }
    }

    mutating func acceptWord(_ word: String) -> Bool {
        guard current.isIdentifier(word) else { return false }
        take()
        return true
    }

    mutating func identifier(_ what: String) throws(ProtoCompileError) -> String {
        guard current.kind == .identifier else { throw error("expected \(what)") }
        return take().text
    }

    /// A dotted name, with a leading `.` when written fully qualified.
    mutating func fullIdentifier(_ what: String) throws(ProtoCompileError) -> String {
        var name = accept(".") ? "." : ""
        name += try identifier(what)
        while current.isSymbol("."), peek().kind == .identifier {
            take()
            name += "." + take().text
        }
        return name
    }

    /// One or more adjacent string literals, concatenated.
    mutating func strings(_ what: String) throws(ProtoCompileError) -> [UInt8] {
        guard current.kind == .string else { throw error("expected \(what)") }
        var bytes: [UInt8] = []
        while current.kind == .string { bytes += take().bytes }
        return bytes
    }

    /// A signed integer that fits `Int64`, or `max` when `allowMax` (returned as `Int64.max`).
    mutating func integer(_ what: String, allowMax: Bool = false) throws(ProtoCompileError) -> Int64 {
        if allowMax, acceptWord("max") { return .max }
        let negative = accept("-")
        let token = current
        guard token.kind == .integer, let magnitude = Self.magnitude(token.text) else {
            throw error("expected \(what)")
        }
        take()
        if negative {
            guard magnitude <= UInt64(Int64.max) + 1 else { throw error("integer out of range", at: token) }
            return magnitude == UInt64(Int64.max) + 1 ? .min : -Int64(magnitude)
        }
        guard magnitude <= UInt64(Int64.max) else { throw error("integer out of range", at: token) }
        return Int64(magnitude)
    }

    /// The value of an integer literal: `0x` hexadecimal, a leading `0` octal, otherwise decimal; `nil` past 64 bits.
    static func magnitude(_ text: String) -> UInt64? {
        let lower = text.lowercased()
        if lower.hasPrefix("0x") { return UInt64(lower.dropFirst(2), radix: 16) }
        if lower.count > 1, lower.hasPrefix("0") { return UInt64(lower.dropFirst(), radix: 8) }
        return UInt64(lower, radix: 10)
    }

    /// A constant: a signed number or identifier, strings, or a message literal in braces.
    mutating func value() throws(ProtoCompileError) -> ProtoOptionValue {
        if current.isSymbol("{") { return .aggregate(try aggregate()) }
        if current.kind == .string { return .string(try strings("a string")) }
        let negative = accept("-")
        if !negative { _ = accept("+") }
        let token = take()
        switch token.kind {
            case .integer: return .integer(token.text, negative: negative)
            case .float: return .float(token.text, negative: negative)
            case .identifier: return .identifier(token.text, negative: negative)
            default: throw error("expected a constant", at: token)
        }
    }

    /// The tokens of a message literal, between (and without) its outer braces.
    mutating func aggregate() throws(ProtoCompileError) -> [ProtoToken] {
        let open = current
        try expect("{")
        var depth = 1
        var tokens: [ProtoToken] = []
        while true {
            let token = take()
            if token.kind == .end { throw error("unterminated message literal", at: open) }
            if token.isSymbol("{") || token.isSymbol("<") { depth += 1 }
            if token.isSymbol("}") || token.isSymbol(">") {
                depth -= 1
                if depth == 0 { break }
            }
            tokens.append(token)
        }
        tokens.append(ProtoToken(kind: .end, text: "", line: open.line, column: open.column))
        return tokens
    }
}
