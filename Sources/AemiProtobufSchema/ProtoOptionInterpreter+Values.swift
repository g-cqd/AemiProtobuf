import AemiProtobufCore

// Setting an option's value on the options message, field by field. Apart from ProtoOptionInterpreter.swift
// to keep each file within the 250 lines SourceStructureTests allows.
extension ProtoOptionInterpreter {
    /// Sets one option: walks its name path down from the options message (creating the messages it passes through), sets or
    /// appends the value at the end, and writes the messages back up.
    func apply(
        _ option: ParsedOption,
        to root: inout DynamicMessage,
        _ rootType: DynamicMessageType,
        scope: String,
        file: String
    ) throws(ProtoCompileError) {
        func fail(_ message: String) -> ProtoCompileError {
            ProtoCompileError(file: file, line: option.line, column: option.column, message: message)
        }
        let written = option.name
            .map { part -> String in
                switch part {
                    case .field(let name): name
                    case .extension(let name): "(" + name + ")"
                }
            }
            .joined(separator: ".")
        var chain = [root]
        var path: [DynamicField] = []
        var type = rootType
        for (position, part) in option.name.enumerated() {
            let field: DynamicField?
            switch part {
                case .field(let name):
                    field = type.field(named: name).flatMap { $0.isExtension || $0.name != name ? nil : $0 }
                case .extension(let name):
                    field = symbols.resolve(name, in: scope, accept: { $0 == .extension })
                        .flatMap { type.field(named: "[" + $0 + "]") }
            }
            guard let field else { throw fail("Option \"\(written)\" unknown.") }
            path.append(field)
            guard position < option.name.count - 1 else { break }
            guard field.type == .message || field.type == .group, !field.isRepeated,
                let next = field.typeName.flatMap(schema.messageType(named:))
            else { throw fail("Option \"\(written)\" is an atomic type, not a message.") }
            let current = chain[chain.count - 1].fields[field.number]
            if case .message(let existing)? = current {
                chain.append(existing)
            } else {
                chain.append(DynamicMessage(typeName: next.name))
            }
            type = next
        }
        guard let leaf = path.last else { throw fail("Option name is empty.") }
        let value = try value(option.value, for: leaf, scope: scope, fail: fail)
        let last = chain.count - 1
        if let entry = leaf.mapEntry, case .message(let pair) = value {
            guard case .map(var map) = chain[last].fields[leaf.number] ?? .map([:]) else {
                throw fail("Option \"\(written)\".")
            }
            map[pair.fields[1] ?? schema.defaultValue(of: entry.key, typeName: nil)] =
                pair.fields[2] ?? schema.defaultValue(of: entry.value, typeName: entry.valueTypeName)
            chain[last].fields[leaf.number] = .map(map)
        } else if leaf.isRepeated {
            guard case .list(var items) = chain[last].fields[leaf.number] ?? .list([]) else {
                throw fail("Option \"\(written)\".")
            }
            items.append(value)
            chain[last].fields[leaf.number] = .list(items)
        } else {
            guard chain[last].fields[leaf.number] == nil else { throw fail("Option \"\(written)\" was already set.") }
            chain[last].fields[leaf.number] = value
        }
        for position in stride(from: last, to: 0, by: -1) {
            chain[position - 1].fields[path[position - 1].number] = .message(chain[position])
        }
        root = chain[0]
    }

    func value(
        _ written: ProtoOptionValue,
        for field: DynamicField,
        scope: String,
        fail: (String) -> ProtoCompileError
    ) throws(ProtoCompileError) -> DynamicValue {
        if field.type == .message || field.type == .group {
            guard case .aggregate(let tokens) = written, let type = field.typeName.flatMap(schema.messageType(named:))
            else {
                throw fail("Error while parsing option value for \"\(field.name)\": expected a message literal.")
            }
            let symbols = symbols
            var parser = ProtoTextParser(
                schema: schema,
                resolveExtension: { symbols.resolve($0, in: scope, accept: { $0 == .extension }) },
                stream: ProtoTokenStream(tokens, file: "")
            )
            return .message(try parser.parse(as: type))
        }
        do throws(ProtoValueError) {
            return try ProtoValueConverter.convert(
                written,
                to: field.type,
                enumeration: field.typeName.flatMap(schema.enumeration(named:))
            )
        } catch {
            throw fail("\(error.message) for option \"\(field.name)\".")
        }
    }
}
