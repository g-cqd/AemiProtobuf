/// Parses one `.proto` file into a ``ParsedFile`` with an explicit stack of open scopes: each `{` pushes one, each `}` pops it,
/// and every statement is read in the scope on top. Names stay as written; ``ProtoResolver`` resolves them.
struct ProtoFileParser {
    enum Scope {
        case file
        case message(Int)
        case oneof(message: Int, index: Int32)
        case enumeration(Int)
        case service(Int)
        case method(service: Int, index: Int)
        /// An `extend` block: the message index it is in (`nil` at file level) and the extendee as written.
        case extend(scope: Int?, extendee: String)
    }

    var stream: ProtoTokenStream
    var file: ParsedFile
    var scopes: [Scope] = [.file]
    /// The most declarations open at once, as protoc's parser bounds recursion.
    let maxDepth: Int

    init(_ text: String, name: String, maxDepth: Int = 100) throws(ProtoCompileError) {
        stream = ProtoTokenStream(try ProtoTokenizer.tokens(text, file: name), file: name)
        file = ParsedFile(name: name)
        self.maxDepth = maxDepth
    }

    var isProto3: Bool { file.syntax == "proto3" }
    var isEditions: Bool { file.syntax == "editions" }

    mutating func parse() throws(ProtoCompileError) -> ParsedFile {
        try header()
        while true {
            if stream.atEnd {
                guard scopes.count == 1 else {
                    throw stream.error("reached end of input in a declaration: missing \"}\"")
                }
                return file
            }
            if stream.accept(";") { continue }
            if stream.current.isSymbol("}") {
                guard scopes.count > 1 else { throw stream.error("unmatched \"}\"") }
                let close = stream.take()
                if case .oneof(let message, let index) = scopes.removeLast(),
                    !file.messages[message].fields.contains(where: { $0.descriptor.oneofIndex == index })
                {
                    throw stream.error("oneof must have at least one field", at: close)
                }
                continue
            }
            guard let scope = scopes.last else { return file }
            switch scope {
                case .file: try fileStatement()
                case .message(let index): try messageStatement(index, oneof: nil)
                case .oneof(let message, let index): try messageStatement(message, oneof: index)
                case .enumeration(let index): try enumStatement(index)
                case .service(let index): try serviceStatement(index)
                case .method(let service, let index):
                    let option = try optionStatement()
                    file.services[service].methodOptions[index].append(option)
                case .extend(let scope, let extendee): try extendStatement(scope: scope, extendee: extendee)
            }
        }
    }

    mutating func push(_ scope: Scope) throws(ProtoCompileError) {
        guard scopes.count <= maxDepth else { throw stream.error("declarations nested too deeply") }
        try stream.expect("{")
        scopes.append(scope)
    }

    /// `syntax = "proto2" | "proto3";` or `edition = "2023";`, when it is the first statement.
    private mutating func header() throws(ProtoCompileError) {
        if stream.acceptWord("syntax") {
            try stream.expect("=")
            let token = stream.current
            let value = String(decoding: try stream.strings("a syntax"), as: UTF8.self)
            guard value == "proto2" || value == "proto3" else {
                throw stream.error("unrecognized syntax identifier \"\(value)\"", at: token)
            }
            // protoc writes no `syntax` for proto2, declared or not.
            file.syntax = value == "proto2" ? "" : value
            try stream.expect(";")
        } else if stream.acceptWord("edition") {
            try stream.expect("=")
            let token = stream.current
            let value = String(decoding: try stream.strings("an edition"), as: UTF8.self)
            guard let edition = ["2023": Int32(1000), "2024": 1001][value] else {
                throw stream.error("unknown edition \"\(value)\"", at: token)
            }
            file.syntax = "editions"
            file.edition = edition
            try stream.expect(";")
        }
    }

    private mutating func fileStatement() throws(ProtoCompileError) {
        let token = stream.current
        guard token.kind == .identifier else { throw stream.error("expected a top-level statement", at: token) }
        switch token.text {
            case "package":
                stream.take()
                guard file.package.isEmpty else { throw stream.error("multiple package definitions", at: token) }
                file.package = try stream.fullIdentifier("a package name")
                try stream.expect(";")
            case "import":
                stream.take()
                if stream.acceptWord("public") {
                    file.publicDependencies.append(Int32(file.dependencies.count))
                } else if stream.acceptWord("weak") {
                    file.weakDependencies.append(Int32(file.dependencies.count))
                }
                file.dependencies.append(String(decoding: try stream.strings("a file name"), as: UTF8.self))
                try stream.expect(";")
            case "option": file.options.append(try optionStatement())
            case "message": try openMessage(parent: nil)
            case "enum": try openEnum(parent: nil)
            case "service": try openService()
            case "extend": try openExtend(scope: nil)
            case "syntax", "edition": throw stream.error("\(token.text) must be the first statement", at: token)
            default: throw stream.error("expected a top-level statement", at: token)
        }
    }

    /// `option name = value;`
    mutating func optionStatement() throws(ProtoCompileError) -> ParsedOption {
        guard stream.acceptWord("option") else { throw stream.error("expected \"option\"") }
        let option = try optionAssignment()
        try stream.expect(";")
        return option
    }

    /// `name = value`, the name a path of fields and parenthesized extensions.
    mutating func optionAssignment() throws(ProtoCompileError) -> ParsedOption {
        let start = stream.current
        var parts: [ParsedOption.Part] = []
        repeat {
            if stream.accept("(") {
                parts.append(.extension(try stream.fullIdentifier("an extension name")))
                try stream.expect(")")
            } else {
                parts.append(.field(try stream.identifier("an option name")))
            }
        } while stream.accept(".")
        try stream.expect("=")
        return ParsedOption(name: parts, value: try stream.value(), line: start.line, column: start.column)
    }

    /// The full name of something named `name` declared in message `parent` (or at file level).
    func fullName(_ name: String, in parent: Int?) -> String {
        let scope = file.scope(of: parent)
        return scope.isEmpty ? name : scope + "." + name
    }
}
