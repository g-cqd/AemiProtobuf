import AemiProtobufCore

/// Interprets every option of the compiled files into the bytes protoc writes: each declaration's options become a message of
/// its options type (`google.protobuf.FileOptions`, `FieldOptions`, …), with custom options as the extensions they are, and
/// are encoded as ``DynamicSchema`` encodes, fields in number order. The option types come from the embedded `descriptor.proto`
/// and the compiled files.
struct ProtoOptionInterpreter {
    /// A nested message of an options message, and where it goes back.
    struct OptionNode {
        var message: DynamicMessage
        let parent: Int
        let field: Int32
        let position: Int?
    }

    let symbols: ProtoSymbols
    let schema: DynamicSchema

    init(files: [ParsedFile], symbols: ProtoSymbols) {
        self.symbols = symbols
        // The option types always come from the embedded descriptor.proto, whose own options (`retention`, …) are interpreted;
        // a compiled descriptor.proto has none yet. Custom options extend the same type names, so they still resolve.
        var descriptors = files.filter { $0.name != "google/protobuf/descriptor.proto" }.map(ProtoFileBuilder.build)
        descriptors.insert(contentsOf: EmbeddedBase64.descriptorProto, at: 0)
        schema = DynamicSchema(FileDescriptorSet(files: descriptors))
    }

    func interpret(_ files: inout [ParsedFile]) throws(ProtoCompileError) {
        for index in files.indices { try interpretFile(&files[index]) }
    }

    private func interpretFile(_ file: inout ParsedFile) throws(ProtoCompileError) {
        let name = file.name
        file.optionBytes = try encode(file.options, "FileOptions", scope: file.package, file: name)
        for index in file.messages.indices {
            let scope = file.messages[index].fullName
            if let bytes = try encode(file.messages[index].options, "MessageOptions", scope: scope, file: name) {
                file.messages[index].descriptor.options = bytes
            }
            for position in file.messages[index].fields.indices {
                file.messages[index].fields[position].descriptor.options = try encode(
                    file.messages[index].fields[position].options, "FieldOptions", scope: scope, file: name)
            }
            for position in file.messages[index].descriptor.oneofs.indices {
                file.messages[index].descriptor.oneofs[position].options = try encode(
                    file.messages[index].oneofOptions[position], "OneofOptions", scope: scope, file: name)
            }
            let messageSet = file.messages[index].descriptor.messageSetWireFormat
            for position in file.messages[index].descriptor.extensionRanges.indices {
                file.messages[index].descriptor.extensionRanges[position].options = try encode(
                    file.messages[index].rangeOptions[position], "ExtensionRangeOptions", scope: scope, file: name)
                if messageSet, file.messages[index].rangesToMax.contains(position) {
                    file.messages[index].descriptor.extensionRanges[position].end = Int32.max
                }
            }
        }
        for index in file.enums.indices {
            let scope = file.scope(of: file.enums[index].parent)
            file.enums[index].descriptor.options = try encode(
                file.enums[index].options, "EnumOptions", scope: scope, file: name)
            for position in file.enums[index].descriptor.values.indices {
                file.enums[index].descriptor.values[position].options = try encode(
                    file.enums[index].valueOptions[position], "EnumValueOptions", scope: scope, file: name)
            }
        }
        for index in file.extensions.indices {
            file.extensions[index].descriptor.options = try encode(
                file.extensions[index].options, "FieldOptions", scope: file.scope(of: file.extensions[index].scope),
                file: name)
        }
        for index in file.services.indices {
            let scope = file.services[index].fullName
            file.services[index].descriptor.options = try encode(
                file.services[index].options, "ServiceOptions", scope: file.package, file: name)
            for position in file.services[index].descriptor.methods.indices {
                let options = try encode(
                    file.services[index].methodOptions[position], "MethodOptions", scope: scope, file: name)
                let body = file.services[index].methodBodies.contains(position)
                file.services[index].descriptor.methods[position].options = options ?? (body ? [] : nil)
            }
        }
    }

    /// The encoded options message, or `nil` when there are no options.
    private func encode(_ options: [ParsedOption], _ typeName: String, scope: String, file: String)
        throws(ProtoCompileError) -> [UInt8]?
    {
        guard !options.isEmpty else { return nil }
        guard let type = schema.messageType(named: "google.protobuf." + typeName) else {
            throw ProtoCompileError(file: file, message: "google.protobuf.\(typeName) is not defined")
        }
        var root = DynamicMessage(typeName: type.name)
        for option in options { try apply(option, to: &root, type, scope: scope, file: file) }
        do throws(DynamicMessageError) {
            let bytes = try schema.encode(withoutSourceRetention(root))
            return bytes.isEmpty ? nil : bytes
        } catch {
            throw ProtoCompileError(file: file, message: "cannot encode options: \(error)")
        }
    }

    /// The options without the fields declared `retention = RETENTION_SOURCE`, at any depth: protoc keeps them out of the
    /// descriptors it writes. Nested messages are visited breadth first, then put back last first.
    private func withoutSourceRetention(_ root: DynamicMessage) -> DynamicMessage {
        var nodes = [OptionNode(message: root, parent: -1, field: 0, position: nil)]
        var index = 0
        while index < nodes.count {
            let type = schema.messageType(named: nodes[index].message.typeName)
            for (number, value) in nodes[index].message.fields {
                guard let field = type?.field(number: number) else { continue }
                if OptionsReader.varint(field.descriptor.options, 17) == 2 {
                    nodes[index].message.fields[number] = nil
                } else if case .message(let nested) = value {
                    nodes.append(OptionNode(message: nested, parent: index, field: number, position: nil))
                } else if case .list(let items) = value {
                    for (position, item) in items.enumerated() {
                        if case .message(let nested) = item {
                            nodes.append(OptionNode(message: nested, parent: index, field: number, position: position))
                        }
                    }
                }
            }
            index += 1
        }
        for index in nodes.indices.dropFirst().reversed() {
            let (message, parent, field, position) = (
                nodes[index].message, nodes[index].parent, nodes[index].field, nodes[index].position
            )
            if let position, case .list(var items)? = nodes[parent].message.fields[field] {
                items[position] = .message(message)
                nodes[parent].message.fields[field] = .list(items)
            } else {
                nodes[parent].message.fields[field] = .message(message)
            }
        }
        return nodes[0].message
    }

    /// Sets one option: walks its name path down from the options message (creating the messages it passes through), sets or
    /// appends the value at the end, and writes the messages back up.
    private func apply(
        _ option: ParsedOption, to root: inout DynamicMessage, _ rootType: DynamicMessageType, scope: String,
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

    private func value(
        _ written: ProtoOptionValue, for field: DynamicField, scope: String, fail: (String) -> ProtoCompileError
    ) throws(ProtoCompileError) -> DynamicValue {
        if field.type == .message || field.type == .group {
            guard case .aggregate(let tokens) = written, let type = field.typeName.flatMap(schema.messageType(named:))
            else {
                throw fail("Error while parsing option value for \"\(field.name)\": expected a message literal.")
            }
            let symbols = symbols
            var parser = ProtoTextParser(
                schema: schema, resolveExtension: { symbols.resolve($0, in: scope, accept: { $0 == .extension }) },
                stream: ProtoTokenStream(tokens, file: ""))
            return .message(try parser.parse(as: type))
        }
        do throws(ProtoValueError) {
            return try ProtoValueConverter.convert(
                written, to: field.type, enumeration: field.typeName.flatMap(schema.enumeration(named:)))
        } catch {
            throw fail("\(error.message) for option \"\(field.name)\".")
        }
    }
}
