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
                place(fields.take(typeName: frame.type.name), in: &frames[frames.count - 1], field: frame.field)
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
        let field = try fieldName(frames[top].type)
        guard frames[top].seen.insert(field.number).inserted || field.isRepeated else {
            throw stream.error("non-repeated field \"\(field.name)\" is specified multiple times")
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

    private mutating func fieldName(_ type: DynamicMessageType) throws(ProtoCompileError) -> DynamicField {
        let token = stream.current
        if stream.accept("[") {
            let written = try stream.fullIdentifier("an extension name")
            try stream.expect("]")
            let full = resolveExtension(written) ?? written
            guard let field = type.field(named: "[" + full + "]") else {
                throw stream.error("\"\(written)\" is not an extension of \(type.name)", at: token)
            }
            return field
        }
        let name = try stream.identifier("a field name")
        if let field = type.field(named: name), !field.isExtension { return field }
        if let group = type.fields.first(where: { $0.type == .group && $0.typeName?.hasSuffix("." + name) == true }) {
            return group
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
}
