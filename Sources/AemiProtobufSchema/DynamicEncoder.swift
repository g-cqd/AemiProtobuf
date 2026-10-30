import AemiProtobufCore

/// One ``DynamicSchema/encode(_:limits:)``, without recursion: a stack of open messages. Each step writes the next field of the
/// innermost one; a nested message pushes a frame and is written before its parent continues, and a frame that has written
/// every field writes its unknown fields and closes its length prefix or group.
struct DynamicEncoder {
    struct Frame {
        let message: DynamicMessage
        let type: DynamicMessageType
        let numbers: [Int32]
        var position = 0
        /// The next element of the repeated field or map at `position`.
        var element = 0
        /// The entries of the map at `position`, by key.
        var entries: [(key: DynamicValue, value: DynamicValue)] = []
        let close: Close
    }

    enum Close {
        case root
        case message(MessageMark)
        case group(FieldNumber)
        /// A map entry's message value: the value's prefix, then the entry's.
        case entry(value: MessageMark, entry: MessageMark)
    }

    let schema: DynamicSchema
    var writer: WireWriter
    var frames: [Frame] = []
    let limits: WireLimits

    init(schema: DynamicSchema, limits: WireLimits) {
        self.schema = schema
        self.limits = limits
        writer = WireWriter(limits: limits)
    }

    mutating func run(_ message: DynamicMessage) throws(DynamicMessageError) -> [UInt8] {
        try push(message, close: .root)
        while !frames.isEmpty { try step() }
        return writer.bytes
    }

    private mutating func push(_ message: DynamicMessage, close: Close) throws(DynamicMessageError) {
        guard let type = schema.messageType(named: message.typeName) else {
            throw .unknownMessageType(message.typeName)
        }
        frames.append(Frame(message: message, type: type, numbers: message.fields.keys.sorted(), close: close))
    }

    /// Writes the next field of the innermost message, or closes it.
    private mutating func step() throws(DynamicMessageError) {
        let top = frames.count - 1
        let frame = frames[top]
        guard frame.position < frame.numbers.count else {
            writer.appendUnknownFields(frame.message.unknownFields)
            frames.removeLast()
            try wire { (writer) throws(WireError) in try Self.close(frame.close, &writer) }
            return
        }
        let number = frame.numbers[frame.position]
        guard let field = frame.type.field(number: number), let tag = FieldNumber(rawValue: UInt32(number)),
            let value = frame.message.fields[number]
        else { throw .unknownField(message: frame.type.name, number: number) }
        let mismatch = DynamicMessageError.typeMismatch(message: frame.type.name, field: field.name)
        if let entry = field.mapEntry {
            guard case .map(let map) = value else { throw mismatch }
            try writeEntry(of: map, field, entry, tag, top: top, mismatch: mismatch)
        } else if field.isRepeated {
            guard case .list(let items) = value else { throw mismatch }
            try writeElements(items, field, tag, top: top, mismatch: mismatch)
        } else {
            frames[top].position += 1
            if field.type == .message || field.type == .group {
                guard case .message(let child) = value, child.typeName == field.typeName else { throw mismatch }
                try open(child, field, tag)
            } else if field.hasPresence || !value.isImplicitDefault {
                guard DynamicScalarWriter.write(value, as: field.type, field: tag, into: &writer) else {
                    throw mismatch
                }
            }
        }
    }

    private mutating func writeElements(
        _ items: [DynamicValue], _ field: DynamicField, _ tag: FieldNumber, top: Int, mismatch: DynamicMessageError
    ) throws(DynamicMessageError) {
        if field.isPacked {
            frames[top].position += 1
            guard !items.isEmpty else { return }
            var run = WireWriter(limits: limits)
            for item in items {
                guard DynamicScalarWriter.payload(item, as: field.type, into: &run) else { throw mismatch }
            }
            writer.appendTag(tag, .lengthDelimited)
            writer.appendBytes(run.bytes)
            return
        }
        var index = frames[top].element
        while index < items.count {
            let item = items[index]
            index += 1
            if field.type == .message || field.type == .group {
                guard case .message(let child) = item, child.typeName == field.typeName else { throw mismatch }
                frames[top].element = index
                try open(child, field, tag)
                return
            }
            guard DynamicScalarWriter.write(item, as: field.type, field: tag, into: &writer) else { throw mismatch }
        }
        frames[top].element = 0
        frames[top].position += 1
    }

    /// Writes the next entry of a map, by key. Both key and value are written, at their defaults too, as protoc does.
    private mutating func writeEntry(
        of map: [DynamicValue: DynamicValue], _ field: DynamicField, _ entry: DynamicField.MapEntry, _ tag: FieldNumber,
        top: Int, mismatch: DynamicMessageError
    ) throws(DynamicMessageError) {
        if frames[top].element == 0 { frames[top].entries = map.sorted { DynamicValue.keyPrecedes($0.key, $1.key) } }
        let position = frames[top].element
        guard position < frames[top].entries.count else {
            frames[top].element = 0
            frames[top].entries = []
            frames[top].position += 1
            return
        }
        frames[top].element += 1
        let (key, value) = frames[top].entries[position]
        let mark = try wire { (writer) throws(WireError) in try writer.beginMessage(field: tag) }
        guard DynamicScalarWriter.write(key, as: entry.key.type, field: 1, into: &writer) else { throw mismatch }
        guard entry.value.type == .message else {
            guard DynamicScalarWriter.write(value, as: entry.value.type, field: 2, into: &writer) else {
                throw mismatch
            }
            try wire { (writer) throws(WireError) in try writer.endMessage(mark) }
            return
        }
        guard case .message(let child) = value, child.typeName == entry.valueTypeName else { throw mismatch }
        let valueMark = try wire { (writer) throws(WireError) in try writer.beginMessage(field: 2) }
        try push(child, close: .entry(value: valueMark, entry: mark))
    }

    private mutating func open(_ child: DynamicMessage, _ field: DynamicField, _ tag: FieldNumber)
        throws(DynamicMessageError)
    {
        guard field.type == .group else {
            let mark = try wire { (writer) throws(WireError) in try writer.beginMessage(field: tag) }
            try push(child, close: .message(mark))
            return
        }
        guard frames.count <= limits.maxDepth else {
            throw .wire(.depthExceeded(limit: limits.maxDepth, at: writer.bytes.count))
        }
        writer.appendTag(tag, .startGroup)
        try push(child, close: .group(tag))
    }

    private static func close(_ close: Close, _ writer: inout WireWriter) throws(WireError) {
        switch close {
            case .root: break
            case .message(let mark): try writer.endMessage(mark)
            case .group(let tag): writer.appendTag(tag, .endGroup)
            case .entry(let value, let entry):
                try writer.endMessage(value)
                try writer.endMessage(entry)
        }
    }

    /// Runs a writer operation, its `WireError` as a ``DynamicMessageError``.
    private mutating func wire<R>(_ body: (inout WireWriter) throws(WireError) -> R) throws(DynamicMessageError) -> R {
        do throws(WireError) {
            return try body(&writer)
        } catch {
            throw .wire(error)
        }
    }
}
