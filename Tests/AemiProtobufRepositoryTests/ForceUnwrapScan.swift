/// Finds force unwraps (`x!`), force casts (`as!`), force tries (`try!`) and implicitly unwrapped optionals (`T!`) in Swift
/// source, after comments and string literals are blanked: each traps on input it did not expect, and the library reads attacker
/// input (roadmap 0013). Lexical, as `RecursionScan` is: `!=`, prefix `!` and `!` inside a string or a comment are not findings.
enum ForceUnwrapScan {
    /// Every force, as `file:line: text`.
    static func findings(_ files: [(name: String, text: String)]) -> [String] {
        var found: [String] = []
        for file in files {
            let source = Array(RecursionScan.blank(file.text, language: .swift).unicodeScalars)
            var line = 1
            for index in source.indices {
                if source[index] == "\n" { line += 1 }
                guard source[index] == "!", index > 0 else { continue }
                let before = source[index - 1]
                let after = index + 1 < source.count ? source[index + 1] : " "
                guard after != "=" else { continue }
                // A postfix `!` follows an identifier, a closing bracket or a `?`; a prefix `!` follows anything else.
                guard
                    RecursionScan.isIdentifier(before) || before == ")" || before == "]" || before == ">"
                        || before == "?"
                else { continue }
                found.append("\(file.name):\(line): force with '!'")
            }
        }
        return found
    }
}
