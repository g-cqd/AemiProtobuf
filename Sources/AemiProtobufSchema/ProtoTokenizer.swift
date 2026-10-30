/// Splits `.proto` source, or text-format source, into tokens as protoc's tokenizer does: identifiers, decimal, hexadecimal
/// and octal integers, floats, quoted strings with C escapes, and punctuation; `//` and `/* */` comments (and `#` comments in
/// text format) are skipped.
struct ProtoTokenizer {
    private let source: [UInt8]
    private let file: String
    private let hashComments: Bool
    private var index = 0
    private var line = 1
    private var column = 1

    init(_ text: String, file: String, hashComments: Bool = false) {
        source = Array(text.utf8)
        self.file = file
        self.hashComments = hashComments
    }

    /// Every token, the last one `.end`.
    static func tokens(_ text: String, file: String, hashComments: Bool = false) throws(ProtoCompileError)
        -> [ProtoToken]
    {
        var tokenizer = ProtoTokenizer(text, file: file, hashComments: hashComments)
        var tokens: [ProtoToken] = []
        while true {
            let token = try tokenizer.next()
            tokens.append(token)
            if token.kind == .end { return tokens }
        }
    }

    private func peek(_ offset: Int = 0) -> UInt8? {
        index + offset < source.count ? source[index + offset] : nil
    }

    private mutating func advance() {
        if source[index] == UInt8(ascii: "\n") {
            line += 1
            column = 1
        } else if source[index] & 0xC0 != 0x80 {
            column += 1
        }
        index += 1
    }

    func error(_ message: String, line: Int? = nil, column: Int? = nil) -> ProtoCompileError {
        ProtoCompileError(file: file, line: line ?? self.line, column: column ?? self.column, message: message)
    }

    private mutating func skipSpaceAndComments() throws(ProtoCompileError) {
        while let byte = peek() {
            if byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\t") || byte == UInt8(ascii: "\n")
                || byte == UInt8(ascii: "\r") || byte == 0x0B || byte == 0x0C
            {
                advance()
            } else if byte == UInt8(ascii: "/"), peek(1) == UInt8(ascii: "/") {
                while let next = peek(), next != UInt8(ascii: "\n") { advance() }
            } else if hashComments, byte == UInt8(ascii: "#") {
                while let next = peek(), next != UInt8(ascii: "\n") { advance() }
            } else if byte == UInt8(ascii: "/"), peek(1) == UInt8(ascii: "*") {
                let (startLine, startColumn) = (line, column)
                advance()
                advance()
                while !(peek() == UInt8(ascii: "*") && peek(1) == UInt8(ascii: "/")) {
                    guard peek() != nil else {
                        throw error("unterminated comment", line: startLine, column: startColumn)
                    }
                    advance()
                }
                advance()
                advance()
            } else {
                return
            }
        }
    }

    mutating func next() throws(ProtoCompileError) -> ProtoToken {
        try skipSpaceAndComments()
        let (startLine, startColumn, start) = (line, column, index)
        guard let byte = peek() else { return ProtoToken(kind: .end, text: "", line: line, column: column) }
        if Self.isLetter(byte) {
            while let next = peek(), Self.isLetter(next) || Self.isDigit(next) { advance() }
            return ProtoToken(kind: .identifier, text: text(from: start), line: startLine, column: startColumn)
        }
        if Self.isDigit(byte) || byte == UInt8(ascii: ".") && peek(1).map(Self.isDigit) == true {
            let kind = try number()
            return ProtoToken(kind: kind, text: text(from: start), line: startLine, column: startColumn)
        }
        if byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'") {
            let bytes = try string(quote: byte)
            return ProtoToken(
                kind: .string, text: text(from: start), bytes: bytes, line: startLine, column: startColumn)
        }
        guard byte < 0x80, byte > 0x20 else { throw error("unexpected character") }
        advance()
        return ProtoToken(kind: .symbol, text: text(from: start), line: startLine, column: startColumn)
    }

    private func text(from start: Int) -> String { String(decoding: source[start ..< index], as: UTF8.self) }

    /// Reads a number: `0x` hexadecimal, `0` octal, decimal, or a float (a `.`, an exponent, or an `f` suffix).
    private mutating func number() throws(ProtoCompileError) -> ProtoToken.Kind {
        if peek() == UInt8(ascii: "0"), let x = peek(1), x == UInt8(ascii: "x") || x == UInt8(ascii: "X") {
            advance()
            advance()
            guard peek().map(Self.isHexDigit) == true else { throw error("\"0x\" must be followed by hex digits") }
            while let next = peek(), Self.isHexDigit(next) { advance() }
            return .integer
        }
        var isFloat = false
        while let next = peek(), Self.isDigit(next) { advance() }
        if peek() == UInt8(ascii: ".") {
            isFloat = true
            advance()
            while let next = peek(), Self.isDigit(next) { advance() }
        }
        if let e = peek(), e == UInt8(ascii: "e") || e == UInt8(ascii: "E") {
            isFloat = true
            advance()
            if let sign = peek(), sign == UInt8(ascii: "+") || sign == UInt8(ascii: "-") { advance() }
            guard peek().map(Self.isDigit) == true else { throw error("\"e\" must be followed by an exponent") }
            while let next = peek(), Self.isDigit(next) { advance() }
        }
        if let f = peek(), f == UInt8(ascii: "f") || f == UInt8(ascii: "F") {
            isFloat = true
            advance()
        }
        if let next = peek(), Self.isLetter(next) { throw error("need space between number and identifier") }
        return isFloat ? .float : .integer
    }

    private mutating func string(quote: UInt8) throws(ProtoCompileError) -> [UInt8] {
        let (startLine, startColumn) = (line, column)
        advance()
        var bytes: [UInt8] = []
        while true {
            guard let byte = peek(), byte != UInt8(ascii: "\n") else {
                throw error("unterminated string literal", line: startLine, column: startColumn)
            }
            advance()
            if byte == quote { return bytes }
            if byte == UInt8(ascii: "\\") {
                try escape(into: &bytes)
            } else {
                bytes.append(byte)
            }
        }
    }

    private mutating func escape(into bytes: inout [UInt8]) throws(ProtoCompileError) {
        guard let byte = peek() else { throw error("unterminated string literal") }
        advance()
        switch byte {
            case UInt8(ascii: "a"): bytes.append(7)
            case UInt8(ascii: "b"): bytes.append(8)
            case UInt8(ascii: "f"): bytes.append(12)
            case UInt8(ascii: "n"): bytes.append(10)
            case UInt8(ascii: "r"): bytes.append(13)
            case UInt8(ascii: "t"): bytes.append(9)
            case UInt8(ascii: "v"): bytes.append(11)
            case UInt8(ascii: "\\"), UInt8(ascii: "'"), UInt8(ascii: "\""), UInt8(ascii: "?"): bytes.append(byte)
            case UInt8(ascii: "x"), UInt8(ascii: "X"):
                var value = 0
                var count = 0
                while count < 2, let next = peek(), Self.isHexDigit(next) {
                    value = value * 16 + Self.hexValue(next)
                    advance()
                    count += 1
                }
                guard count > 0 else { throw error("expected hex digits for escape sequence") }
                bytes.append(UInt8(value))
            case UInt8(ascii: "0") ... UInt8(ascii: "7"):
                var value = Int(byte - 48)
                var count = 1
                while count < 3, let next = peek(), next >= 48, next <= 55 {
                    value = value * 8 + Int(next - 48)
                    advance()
                    count += 1
                }
                bytes.append(UInt8(truncatingIfNeeded: value))
            case UInt8(ascii: "u"), UInt8(ascii: "U"):
                let width = byte == UInt8(ascii: "u") ? 4 : 8
                var value: UInt32 = 0
                for _ in 0 ..< width {
                    guard let next = peek(), Self.isHexDigit(next) else { throw error("expected hex digits for \\u") }
                    value = value * 16 + UInt32(Self.hexValue(next))
                    advance()
                }
                guard let scalar = Unicode.Scalar(value) else { throw error("invalid unicode escape") }
                bytes.append(contentsOf: Array(String(Character(scalar)).utf8))
            default: throw error("invalid escape sequence in string literal")
        }
    }

    static func isLetter(_ byte: UInt8) -> Bool {
        (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || byte == UInt8(ascii: "_")
    }

    static func isDigit(_ byte: UInt8) -> Bool { byte >= 48 && byte <= 57 }

    static func isHexDigit(_ byte: UInt8) -> Bool {
        isDigit(byte) || (byte >= 65 && byte <= 70) || (byte >= 97 && byte <= 102)
    }

    static func hexValue(_ byte: UInt8) -> Int {
        isDigit(byte) ? Int(byte - 48) : Int((byte | 0x20) - 97 + 10)
    }
}
