/// Writes a ``DynamicMessage`` in text format on one line: `name: value`, `name { … }`, `[extension]: value`, map entries as
/// `{ key: … value: … }`. Iterative: a stack of what is still to be written.
struct ProtoTextPrinter {
    let schema: DynamicSchema

    enum Work {
        case text(String)
        case message(DynamicMessage)
    }

    func print(_ message: DynamicMessage) -> String {
        var out = ""
        var stack: [Work] = [.message(message)]
        while let work = stack.popLast() {
            switch work {
                case .text(let text): out += text
                case .message(let message):
                    out += "{"
                    stack.append(.text(" }"))
                    for item in entries(message).reversed() { stack.append(contentsOf: item.reversed()) }
            }
        }
        return out
    }

    /// Each field's entries, in number order: each an array of work in the order it is written.
    private func entries(_ message: DynamicMessage) -> [[Work]] {
        guard let type = schema.messageType(named: message.typeName) else { return [] }
        var result: [[Work]] = []
        for number in message.fields.keys.sorted() {
            guard let field = type.field(number: number), let value = message.fields[number] else { continue }
            let name =
                field.isExtension
                ? field.jsonName
                : field.type == .group ? String(field.typeName?.split(separator: ".").last ?? "") : field.name
            let enumeration = field.typeName.flatMap(schema.enumeration(named:))
            func one(_ value: DynamicValue) -> [Work] {
                if case .message(let nested) = value { return [.text(" " + name + " "), .message(nested)] }
                return [.text(" " + name + ": " + ProtoLiteral.text(value, enumeration: enumeration))]
            }
            switch value {
                case .list(let items): for item in items { result.append(one(item)) }
                case .map(let map):
                    guard let entry = field.mapEntry else { continue }
                    for (key, item) in map.sorted(by: { DynamicValue.keyPrecedes($0.key, $1.key) }) {
                        var text = " " + name + " { key: " + ProtoLiteral.text(key, enumeration: nil)
                        if case .message(let nested) = item {
                            result.append([.text(text + " value "), .message(nested), .text(" }")])
                        } else {
                            let valueEnum = entry.valueTypeName.flatMap(schema.enumeration(named:))
                            text += " value: " + ProtoLiteral.text(item, enumeration: valueEnum) + " }"
                            result.append([.text(text)])
                        }
                    }
                default: result.append(one(value))
            }
        }
        return result
    }
}
