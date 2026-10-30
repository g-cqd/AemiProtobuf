/// Reads a message in protobuf's text format into a ``DynamicMessage``: `name: value`, `name { … }` or `name < … >`,
/// `[extension.name]`, lists in `[ … ]`, map entries as `{ key: … value: … }`. Iterative: a stack of open messages, each
/// placed in its parent when its closing bracket comes. Used for message literals in options (roadmap 0002).
struct ProtoTextParser {
    struct Frame {
        let type: DynamicMessageType
        var fields = DynamicFields()
        let close: String?
        let field: DynamicField?
        let inList: Bool
        var seen: Set<Int32> = []
        var oneofs: Set<Int> = []
        /// An expanded `Any`: the type URL, the message read under it written into the enclosing `Any`.
        var anyURL: String?
    }

    let schema: DynamicSchema
    /// The fully qualified name an extension written in brackets denotes, or `nil` to take it as written.
    let resolveExtension: (String) -> String?
    var stream: ProtoTokenStream
    var maxDepth = 100

    mutating func parse(as type: DynamicMessageType) throws(ProtoCompileError) -> DynamicMessage {
        var frames = [Frame(type: type, close: nil, field: nil, inList: false)]
        while true {
            let token = stream.current
            if token.kind == .end {
                guard frames.count == 1 else { throw stream.error("unexpected end of the message literal") }
                return frames[0].fields.take(typeName: type.name)
            }
            if let close = frames[frames.count - 1].close, token.isSymbol(close) {
                stream.take()
                let frame = frames.removeLast()
                var fields = frame.fields
                let message = fields.take(typeName: frame.type.name)
                if let url = frame.anyURL {
                    guard let bytes = try? schema.encode(message) else {
                        throw stream.error("cannot encode the Any's message")
                    }
                    frames[frames.count - 1].fields.values[1] = .string(url)
                    frames[frames.count - 1].fields.values[2] = .bytes(bytes)
                } else {
                    place(message, in: &frames[frames.count - 1], field: frame.field)
                }
                if frame.inList, let field = frame.field {
                    if stream.accept(",") {
                        try open(field, &frames, inList: true)
                        continue
                    }
                    try stream.expect("]")
                }
                if !stream.accept(",") { _ = stream.accept(";") }
                continue
            }
            try entry(&frames)
        }
    }

    /// One `name: value`, `name: [values]`, or `name { … }` in the innermost message.
    private mutating func entry(_ frames: inout [Frame]) throws(ProtoCompileError) {
        let top = frames.count - 1
        if try expandedAny(&frames) { return }
        guard let field = try fieldName(frames[top].type) else { return }
        guard frames[top].seen.insert(field.number).inserted || field.isRepeated else {
            throw stream.error("non-repeated field \"\(field.name)\" is specified multiple times")
        }
        if let oneof = field.oneofIndex, !frames[top].oneofs.insert(oneof).inserted {
            throw stream.error("field \"\(field.name)\" is specified along with another member of its oneof")
        }
        if field.type == .message || field.type == .group {
            _ = stream.accept(":")
            if stream.accept("[") {
                if !stream.accept("]") { try open(field, &frames, inList: true) }
                return
            }
            try open(field, &frames, inList: false)
            return
        }
        try stream.expect(":")
        if stream.accept("[") {
            if !stream.accept("]") {
                repeat { try scalar(field, into: &frames[top]) } while stream.accept(",")
                try stream.expect("]")
            }
        } else {
            try scalar(field, into: &frames[top])
        }
        if !stream.accept(",") { _ = stream.accept(";") }
    }

    /// `[type.googleapis.com/pkg.Type] { … }` in an `Any`: opens a message of that type, which is encoded into the `Any` when
    /// it closes. `false` when the next entry is not one.
    private mutating func expandedAny(_ frames: inout [Frame]) throws(ProtoCompileError) -> Bool {
        let top = frames.count - 1
        guard stream.current.isSymbol("[") else { return false }
        var lookahead = 1
        while !stream.peek(lookahead).isSymbol("]"), !stream.peek(lookahead).isSymbol("/"),
            stream.peek(lookahead).kind != .end
        {
            lookahead += 1
        }
        guard stream.peek(lookahead).isSymbol("/") else { return false }
        guard frames[top].type.name == "google.protobuf.Any" else { throw stream.error("a type URL outside an Any") }
        let url = try bracketed()
        guard Self.validPercentEscapes(url) else { throw stream.error("invalid percent escape in the type URL \(url)") }
        let name = String(url[url.index(after: url.lastIndex(of: "/") ?? url.startIndex)...])
        guard let type = schema.messageType(named: name) else { throw stream.error("unknown type \(name) in an Any") }
        _ = stream.accept(":")
        let close: String
        if stream.accept("{") {
            close = "}"
        } else {
            try stream.expect("<")
            close = ">"
        }
        guard frames.count <= maxDepth else { throw stream.error("message nested too deeply") }
        var frame = Frame(type: type, close: close, field: nil, inList: false)
        frame.anyURL = url
        frames.append(frame)
        return true
    }

    /// The name between `[` and `]`: every token's text joined, so white space and comments inside it do not count.
    private mutating func bracketed() throws(ProtoCompileError) -> String {
        try stream.expect("[")
        var name = ""
        while !stream.current.isSymbol("]") {
            guard !stream.atEnd else { throw stream.error("expected \"]\"") }
            name += stream.take().text
        }
        stream.take()
        return name
    }

    /// Skips the value of a reserved field name, as C++ skips it: `: value`, `: [ … ]`, or a message.
    private mutating func skipValue() throws(ProtoCompileError) {
        _ = stream.accept(":")
        guard stream.current.isSymbol("{") || stream.current.isSymbol("<") || stream.current.isSymbol("[") else {
            _ = try stream.value()
            if !stream.accept(",") { _ = stream.accept(";") }
            return
        }
        var depth = 0
        repeat {
            let token = stream.take()
            if token.kind == .end { throw stream.error("unterminated value") }
            if token.isSymbol("{") || token.isSymbol("<") || token.isSymbol("[") { depth += 1 }
            if token.isSymbol("}") || token.isSymbol(">") || token.isSymbol("]") { depth -= 1 }
        } while depth > 0
        if !stream.accept(",") { _ = stream.accept(";") }
    }

    private mutating func open(_ field: DynamicField, _ frames: inout [Frame], inList: Bool) throws(ProtoCompileError) {
        let close: String
        if stream.accept("{") {
            close = "}"
        } else if stream.accept("<") {
            close = ">"
        } else {
            throw stream.error("expected \"{\" or \"<\"")
        }
        guard let type = field.typeName.flatMap(schema.messageType(named:)) else {
            throw stream.error("unknown message type \(field.typeName ?? "")")
        }
        guard frames.count <= maxDepth else { throw stream.error("message literal nested too deeply") }
        frames.append(Frame(type: type, close: close, field: field, inList: inList))
    }

    /// The field an entry names: `[extension.name]`, a field name, or a group's type name; `nil` for a reserved name, whose
    /// value is skipped.
    private mutating func fieldName(_ type: DynamicMessageType) throws(ProtoCompileError) -> DynamicField? {
        let token = stream.current
        if stream.current.isSymbol("[") {
            let written = try bracketed()
            let full = resolveExtension(written) ?? written
            guard let field = type.field(named: "[" + full + "]") else {
                throw stream.error("\"\(written)\" is not an extension of \(type.name)", at: token)
            }
            return field
        }
        let name = try stream.identifier("a field name")
        if let field = type.field(named: name), !field.isExtension, field.name == name { return field }
        if let group = type.fields.first(where: {
            $0.isGroupLike(in: type.name) && $0.typeName == type.name + "." + name
        }) {
            return group
        }
        if type.descriptor.reservedNames.contains(name) {
            try skipValue()
            return nil
        }
        throw stream.error("message type \"\(type.name)\" has no field named \"\(name)\"", at: token)
    }

    private mutating func scalar(_ field: DynamicField, into frame: inout Frame) throws(ProtoCompileError) {
        let token = stream.current
        let raw = try stream.value()
        let value: DynamicValue
        do throws(ProtoValueError) {
            value = try ProtoValueConverter.convert(
                raw, to: field.type, enumeration: field.typeName.flatMap(schema.enumeration(named:)),
                textFormat: true)
        } catch {
            throw stream.error("\(error.message) for field \"\(field.name)\"", at: token)
        }
        if case .enumeration(let number) = value, let closed = field.closedEnumValues, !closed.contains(number) {
            throw stream.error("unknown enumeration value \(number) for field \"\(field.name)\"", at: token)
        }
        if field.isRepeated {
            frame.fields.lists[field.number, default: []].append(value)
        } else {
            frame.fields.values[field.number] = value
        }
    }

    /// A finished message into its parent: a map entry as a key and value, a repeated message appended, a singular one set.
    private func place(_ message: DynamicMessage, in frame: inout Frame, field: DynamicField?) {
        guard let field else { return }
        if let entry = field.mapEntry {
            let key = message.fields[1] ?? schema.defaultValue(of: entry.key, typeName: nil)
            let value = message.fields[2] ?? schema.defaultValue(of: entry.value, typeName: entry.valueTypeName)
            frame.fields.maps[field.number, default: [:]][key] = value
        } else if field.isRepeated {
            frame.fields.lists[field.number, default: []].append(.message(message))
        } else {
            frame.fields.values[field.number] = .message(message)
        }
    }

    /// Whether every `%` in `url` is followed by two hexadecimal digits.
    static func validPercentEscapes(_ url: String) -> Bool {
        let bytes = Array(url.utf8)
        var index = 0
        while index < bytes.count {
            if bytes[index] == UInt8(ascii: "%") {
                guard index + 2 < bytes.count, ProtoTokenizer.isHexDigit(bytes[index + 1]),
                    ProtoTokenizer.isHexDigit(bytes[index + 2])
                else { return false }
                index += 3
            } else {
                index += 1
            }
        }
        return true
    }
}
