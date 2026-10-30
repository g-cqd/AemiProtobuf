/// Parses one `.proto` file on its own, without imports: every declaration the compiler reads, with type names left as written
/// (``ProtoCompiler`` resolves them, interprets options and makes protoc's checks). The bounds keep untrusted input from using
/// unbounded memory or nesting.
public struct ProtoParser: Sendable {
    /// Maximum simultaneously open declarations (messages, enumerations, oneofs, services, `extend` blocks).
    public let maxDepth: Int
    /// Maximum UTF-8 source bytes accepted before tokenizing.
    public let maxSourceBytes: Int

    /// Creates a parser with nonnegative source-size and nesting bounds.
    public init(maxDepth: Int = 100, maxSourceBytes: Int = 16 * 1_024 * 1_024) {
        self.maxDepth = max(0, maxDepth)
        self.maxSourceBytes = max(0, maxSourceBytes)
    }

    /// Parses a bounded source, or throws when it is malformed. Type names remain as written in the result.
    /// - Throws: `ProtoParseError` for invalid syntax or exceeded limits, with the line and column.
    /// - Complexity: O(source bytes) time and storage, with at most `maxDepth` open declarations.
    public func parse(_ text: String, name: String = "input.proto") throws(ProtoParseError) -> FileDescriptor {
        guard text.utf8.count <= maxSourceBytes else { throw ProtoParseError("Source byte limit exceeded") }
        do throws(ProtoCompileError) {
            var parser = try ProtoFileParser(text, name: name, maxDepth: maxDepth)
            return ProtoFileBuilder.build(try parser.parse())
        } catch {
            throw ProtoParseError(error.description)
        }
    }

    /// protoc's camel-case JSON name: underscores dropped, the letter after each upper-cased.
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
