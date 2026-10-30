import AemiProtobufCore

/// Writes a ``DynamicMessage`` in text format: `name: value`, `name { … }`, `[extension]: value`, map entries as
/// `{ key: … value: … }`, and unknown fields by number when asked. A message literal is one line in braces; a whole message is
/// one field per line. Iterative: a stack of what is still to be written.
struct ProtoTextPrinter {
    let schema: DynamicSchema
    var printUnknownFields = false

    enum Work {
        case text(String)
        case message(DynamicMessage)
        case unknown([UInt8])
    }

    /// `{ a: 1 b { c: 2 } }`.
    func print(_ message: DynamicMessage) -> String { run([.message(message)]) }

    /// `a: 1\nb { c: 2 }\n`: the top-level fields, one per line.
    func printFields(_ message: DynamicMessage) -> String {
        var works: [Work] = []
        for entry in entries(message) { works += entry + [.text("\n")] }
        if printUnknownFields, !message.unknownFields.isEmpty {
            works += [.unknown(message.unknownFields.bytes), .text("\n")]
        }
        return run(works)
    }

    private func run(_ initial: [Work]) -> String {
        var out = ""
        var stack = Array(initial.reversed())
        while let work = stack.popLast() {
            switch work {
                case .text(let text): out += text
                case .message(let message):
                    var inner: [Work] = [.text("{")]
                    for entry in entries(message) { inner += [.text(" ")] + entry }
                    if printUnknownFields, !message.unknownFields.isEmpty {
                        inner += [.text(" "), .unknown(message.unknownFields.bytes)]
                    }
                    inner.append(.text(" }"))
                    stack += inner.reversed()
                case .unknown(let bytes): stack += unknownEntries(bytes).reversed()
            }
        }
        return out
    }

    /// Each field's entries, in number order, each the work it is written as.
    private func entries(_ message: DynamicMessage) -> [[Work]] {
        guard let type = schema.messageType(named: message.typeName) else { return [] }
        var result: [[Work]] = []
        for number in message.fields.keys.sorted() {
            guard let field = type.field(number: number), let value = message.fields[number] else { continue }
            let name =
                field.isExtension
                ? field.jsonName
                : field.isGroupLike(in: type.name)
                    ? String(field.typeName?.split(separator: ".").last ?? "") : field.name
            let enumeration = field.typeName.flatMap(schema.enumeration(named:))
            func one(_ value: DynamicValue) -> [Work] {
                if case .message(let nested) = value { return [.text(name + " "), .message(nested)] }
                return [.text(name + ": " + ProtoLiteral.text(value, enumeration: enumeration))]
            }
            switch value {
                case .list(let items): result += items.map(one)
                case .map(let map):
                    // Each entry as the `{ key: … value: … }` message it is on the wire.
                    for (key, item) in map.sorted(by: { DynamicValue.keyPrecedes($0.key, $1.key) }) {
                        let pair = DynamicMessage(typeName: field.typeName ?? "", fields: [1: key, 2: item])
                        result.append([.text(name + " "), .message(pair)])
                    }
                default: result.append(one(value))
            }
        }
        return result
    }

    /// Unknown fields as `number: value`: varints in decimal, fixed widths in hexadecimal, length-delimited as quoted bytes,
    /// groups as `number { … }`.
    private func unknownEntries(_ bytes: [UInt8]) -> [Work] {
        var works: [Work] = []
        _ = try? WireReader.withReader(over: bytes) { (reader) throws(WireError) in
            var first = true
            while let tag = try reader.nextTag() {
                if !first { works.append(.text(" ")) }
                first = false
                let number = String(tag.fieldNumber.rawValue)
                switch tag.wireType {
                    case .varint: works.append(.text(number + ": " + String(try reader.readVarint())))
                    case .fixed32: works.append(.text(number + ": 0x" + String(try reader.readFixed32(), radix: 16)))
                    case .fixed64: works.append(.text(number + ": 0x" + String(try reader.readFixed64(), radix: 16)))
                    case .lengthDelimited:
                        // As C++ prints it: a payload that reads as fields is a nested message, anything else a string.
                        let payload = try reader.readBytes()
                        if Self.readsAsFields(payload) {
                            works += [.text(number + " { "), .unknown(payload), .text(" }")]
                        } else {
                            works.append(.text(number + ": " + ProtoLiteral.quoted(payload, keepUTF8: false)))
                        }
                    case .startGroup:
                        let range = try reader.readGroupRange(tag)
                        works += [.text(number + " { "), .unknown(Array(bytes[range])), .text(" }")]
                    case .endGroup: throw .unexpectedEndGroup(at: 0)
                }
            }
        }
        return works
    }

    /// Whether `bytes` are one or more well-formed fields.
    private static func readsAsFields(_ bytes: [UInt8]) -> Bool {
        guard !bytes.isEmpty else { return false }
        let complete = try? WireReader.withReader(over: bytes) { (reader) throws(WireError) -> Bool in
            while let tag = try reader.nextTag() { try reader.skipField(tag) }
            return true
        }
        return complete == true
    }
}
