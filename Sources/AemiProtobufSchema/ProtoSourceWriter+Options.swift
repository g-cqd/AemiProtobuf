extension ProtoSourceWriter {
    /// The options in `bytes` as `(name, value)` pairs, in field-number order: a sub-message as dotted paths into it (its own
    /// sub-messages as text-format literals), a repeated value as one pair per element. Options the schema cannot read are left
    /// out.
    func optionEntries(_ bytes: [UInt8]?, _ typeName: String) -> [(String, String)] {
        guard let bytes, !bytes.isEmpty, let message = try? schema.decode(bytes, as: "google.protobuf." + typeName)
        else {
            return []
        }
        var entries: [(String, String)] = []
        for (name, value, field) in fields(of: message) {
            if case .message(let inner) = value, !field.isRepeated, !inner.fields.isEmpty {
                for (innerName, innerValue, innerField) in fields(of: inner) {
                    entries += leaves(name + "." + innerName, innerValue, innerField)
                }
            } else {
                entries += leaves(name, value, field)
            }
        }
        return entries
    }

    /// A message's set fields in number order, each with the name an option path writes for it.
    private func fields(of message: DynamicMessage) -> [(String, DynamicValue, DynamicField)] {
        guard let type = schema.messageType(named: message.typeName) else { return [] }
        return message.fields.keys.sorted()
            .compactMap { number in
                guard let field = type.field(number: number), let value = message.fields[number] else { return nil }
                let name = field.isExtension ? "(." + field.jsonName.dropFirst().dropLast() + ")" : field.name
                return (name, value, field)
            }
    }

    /// One pair per value: a message as a text-format literal, anything else as a constant.
    private func leaves(_ name: String, _ value: DynamicValue, _ field: DynamicField) -> [(String, String)] {
        let enumeration = field.typeName.flatMap(schema.enumeration(named:))
        let items: [DynamicValue]
        switch value {
            case .list(let list): items = list
            case .map(let map):
                // Each entry as the `{ key: … value: … }` message it is on the wire.
                items = map.sorted { DynamicValue.keyPrecedes($0.key, $1.key) }
                    .map {
                        .message(DynamicMessage(typeName: field.typeName ?? "", fields: [1: $0.key, 2: $0.value]))
                    }
            default: items = [value]
        }
        return items.map { item in
            if case .message(let inner) = item { return (name, ProtoTextPrinter(schema: schema).print(inner)) }
            return (name, ProtoLiteral.text(item, enumeration: enumeration))
        }
    }
}
