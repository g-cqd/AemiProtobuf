/// One token of a `.proto` file or a text-format message: its kind, its text, and where it starts (1-based).
struct ProtoToken: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case identifier
        case integer
        case float
        /// A string literal; ``bytes`` holds its value with escapes decoded.
        case string
        /// One punctuation character; ``text`` is the character.
        case symbol
        case end
    }

    let kind: Kind
    let text: String
    var bytes: [UInt8] = []
    let line: Int
    let column: Int

    func isSymbol(_ character: String) -> Bool { kind == .symbol && text == character }
    func isIdentifier(_ word: String) -> Bool { kind == .identifier && text == word }
}
