/// One `option name = value` (or one entry of a `[...]` list), as written: its name path and its value.
struct ParsedOption: Sendable {
    enum Part: Equatable, Sendable {
        /// A field of the options message, or of the message the previous part named.
        case field(String)
        /// A parenthesized extension name, as written (resolved later).
        case `extension`(String)
    }

    let name: [Part]
    let value: ProtoOptionValue
    let line: Int
    let column: Int
}
