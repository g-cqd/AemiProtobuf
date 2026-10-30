import AemiProtobufCore

extension DynamicDecoder {
    /// Reads the field `tag` starts into `node`. A field the type does not declare, or declares with another wire type, is kept
    /// as unknown; a repeated scalar is read packed or not, whichever came.
    mutating func read(_ tag: FieldTag, from reader: inout WireReader, into node: Int) throws(WireError) {
        guard let field = nodes[node].type.field(number: Int32(tag.fieldNumber.rawValue)) else {
            try reader.readUnknownField(tag, into: &nodes[node].unknown)
            return
        }
        if let entry = field.mapEntry, tag.wireType == .lengthDelimited {
            try readEntry(field, entry, tag, from: &reader, into: node)
            return
        }
        switch (field.type, tag.wireType) {
            case (.message, .lengthDelimited) where field.mapEntry == nil:
                try attach(field, range: try reader.readPayloadRange(), to: node)
            case (.group, .startGroup):
                try attach(field, range: try reader.readGroupRange(tag), to: node)
            case (let type, .lengthDelimited) where field.isRepeated && DynamicField.isPackable(type):
                // Read into an array sized for the run, then stored once: no growth, no dictionary access per element.
                var values: [DynamicValue] = []
                try reader.readPayload { (run) throws(WireError) in
                    values.reserveCapacity(Self.packedCount(of: type, in: run))
                    while !run.isAtEnd {
                        if let value = try self.scalar(field, tag, from: &run, into: node) { values.append(value) }
                    }
                }
                if nodes[node].lists[field.number] == nil {
                    nodes[node].lists[field.number] = values
                } else {
                    nodes[node].lists[field.number, default: []].append(contentsOf: values)
                }
            case (let type, let wire) where field.mapEntry == nil && wire == Self.wireType(of: type):
                try readScalar(field, tag, from: &reader, into: node)
            default:
                try reader.readUnknownField(tag, into: &nodes[node].unknown)
        }
    }

    private mutating func readScalar(
        _ field: DynamicField, _ tag: FieldTag, from reader: inout WireReader, into node: Int
    ) throws(WireError) {
        guard let value = try scalar(field, tag, from: &reader, into: node) else { return }
        if field.isRepeated {
            nodes[node].lists[field.number, default: []].append(value)
        } else {
            clearOneof(of: field, in: node)
            nodes[node].values[field.number] = value
        }
    }

    /// Reads one value of `field`; `nil` when it is a closed enumeration's unknown number, which is kept as an unknown field.
    private mutating func scalar(
        _ field: DynamicField, _ tag: FieldTag, from reader: inout WireReader, into node: Int
    ) throws(WireError) -> DynamicValue? {
        let value = try Self.scalar(field.type, from: &reader, validatingUTF8: field.validatesUTF8, bytes: bytes)
        if case .enumeration(let number) = value, let closed = field.closedEnumValues, !closed.contains(number) {
            nodes[node].unknown.appendVarint(field: tag.fieldNumber, UInt64(bitPattern: Int64(number)))
            return nil
        }
        return value
    }

    /// The number of elements in a packed run of `type`: exact for well-formed input.
    private static func packedCount(of type: FieldType, in run: WireReader) -> Int {
        switch wireType(of: type) {
            case .fixed32: run.remaining / 4
            case .fixed64: run.remaining / 8
            default: run.remainingVarintCount
        }
    }

    /// Queues the message at `range` for `field` of `node`: a new element, or the singular field's node, merged into.
    private mutating func attach(_ field: DynamicField, range: Range<Int>, to node: Int) throws(WireError) {
        let number = field.number
        if field.isRepeated {
            let position = nodes[node].lists[number, default: []].count
            nodes[node].lists[number, default: []].append(.message(DynamicMessage(typeName: field.typeName ?? "")))
            spawn(field.typeName, Link(parent: node, field: number, slot: .element(position)), ranges: [range])
            return
        }
        clearOneof(of: field, in: node)
        if let existing = nodes[node].children[number] {
            jobs.append(Job(node: existing, range: range))
            return
        }
        nodes[node].children[number] = spawn(
            field.typeName, Link(parent: node, field: number, slot: .single), ranges: [range])
    }

    /// Creates the node for a message of the type `typeName` names (a type the set lacks reads every field as unknown) and
    /// queues its bytes.
    @discardableResult
    mutating func spawn(_ typeName: String?, _ link: Link, ranges: [Range<Int>]) -> Int {
        let type =
            typeName.flatMap(schema.messageType(named:))
            ?? DynamicMessageType(name: typeName ?? "", descriptor: MessageDescriptor(name: typeName ?? ""), fields: [])
        nodes.append(Node(type: type, depth: nodes[link.parent].depth + 1, parent: link))
        for range in ranges { jobs.append(Job(node: nodes.count - 1, range: range)) }
        return nodes.count - 1
    }

    /// Setting a member of a oneof clears the others; a message member's node is detached.
    private mutating func clearOneof(of field: DynamicField, in node: Int) {
        guard let oneof = field.oneofIndex, let members = nodes[node].type.oneofMembers[oneof] else { return }
        for member in members where member != field.number {
            nodes[node].values[member] = nil
            if let child = nodes[node].children.removeValue(forKey: member) { nodes[child].parent = nil }
        }
    }
}
