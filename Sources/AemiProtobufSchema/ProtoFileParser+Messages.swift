import AemiProtobufCore

extension ProtoFileParser {
    /// `message Name {`
    mutating func openMessage(parent: Int?) throws(ProtoCompileError) {
        let token = stream.take()
        let name = try stream.identifier("a message name")
        file.messages.append(
            ParsedMessage(
                descriptor: MessageDescriptor(name: name), parent: parent, fullName: fullName(name, in: parent),
                line: token.line, column: token.column))
        try push(.message(file.messages.count - 1))
    }

    /// One statement in a message body, or in a oneof of message `index`.
    mutating func messageStatement(_ index: Int, oneof: Int32?) throws(ProtoCompileError) {
        let token = stream.current
        if oneof != nil {
            if token.isIdentifier("option"), let oneof {
                let option = try optionStatement()
                file.messages[index].oneofOptions[Int(oneof)].append(option)
                return
            }
            try field(in: index, oneof: oneof, extendee: nil)
            return
        }
        switch token.text {
            case "message" where token.kind == .identifier: try openMessage(parent: index)
            case "enum" where token.kind == .identifier: try openEnum(parent: index)
            case "extend" where token.kind == .identifier: try openExtend(scope: index)
            case "option" where token.kind == .identifier: file.messages[index].options.append(try optionStatement())
            case "oneof" where token.kind == .identifier && stream.peek().kind == .identifier:
                stream.take()
                let name = try stream.identifier("a oneof name")
                let position = Int32(file.messages[index].descriptor.oneofs.count)
                file.messages[index].descriptor.oneofs.append(OneofDescriptor(name: name))
                file.messages[index].oneofOptions.append([])
                try push(.oneof(message: index, index: position))
            case "extensions" where token.kind == .identifier: try extensionRanges(index)
            case "reserved" where token.kind == .identifier: try reserved(message: index)
            default: try field(in: index, oneof: nil, extendee: nil)
        }
    }

    /// `extensions 100 to 199, 300 [options];`
    private mutating func extensionRanges(_ index: Int) throws(ProtoCompileError) {
        stream.take()
        var ranges: [DescriptorRange] = []
        var toMax: [Bool] = []
        repeat {
            let (start, end) = try range(max: Int64(FieldNumber.maximum))
            toMax.append(end == .max)
            ranges.append(
                DescriptorRange(
                    start: Int32(start), end: Int32(clamping: end == .max ? Int64(FieldNumber.maximum) : end) &+ 1))
        } while stream.accept(",")
        let options = try bracketOptions()
        try stream.expect(";")
        for (range, max) in zip(ranges, toMax) {
            if max { file.messages[index].rangesToMax.insert(file.messages[index].descriptor.extensionRanges.count) }
            file.messages[index].descriptor.extensionRanges.append(range)
            file.messages[index].rangeOptions.append(options)
        }
    }

    /// `start [to end|max]` within `min ... max`: the end is `Int64.max` for `max`.
    mutating func range(min: Int64 = 1, max: Int64) throws(ProtoCompileError) -> (Int64, Int64) {
        let token = stream.current
        let start = try stream.integer("a number")
        var end = start
        if stream.acceptWord("to") { end = try stream.integer("a number", allowMax: true) }
        guard start >= min, start <= max, end == .max || end <= max && end >= start else {
            throw stream.error("invalid range", at: token)
        }
        return (start, end)
    }

    /// `reserved 2, 9 to 11;` or `reserved "a", "b";` (or bare names in editions).
    private mutating func reserved(message index: Int) throws(ProtoCompileError) {
        let (ranges, names) = try reservation(min: 1, max: Int64(FieldNumber.maximum), endIncluded: false)
        file.messages[index].descriptor.reservedRanges += ranges
        file.messages[index].descriptor.reservedNames += names
    }

    /// The ranges or names after `reserved`: a message's range ends one past its last number, an enumeration's at it.
    mutating func reservation(min: Int64, max: Int64, endIncluded: Bool) throws(ProtoCompileError)
        -> ([DescriptorRange], [String])
    {
        stream.take()
        if stream.current.kind == .string || stream.current.kind == .identifier && isEditions {
            return ([], try reservedNames())
        }
        var ranges: [DescriptorRange] = []
        repeat {
            let (start, end) = try range(min: min, max: max)
            let last = end == .max ? max : end
            ranges.append(DescriptorRange(start: Int32(start), end: Int32(endIncluded ? last : last + 1)))
        } while stream.accept(",")
        try stream.expect(";")
        return (ranges, [])
    }

    /// `[name = value, …]` after a declaration, or none.
    mutating func bracketOptions() throws(ProtoCompileError) -> [ParsedOption] {
        guard stream.accept("[") else { return [] }
        var options: [ParsedOption] = []
        repeat { options.append(try optionAssignment()) } while stream.accept(",")
        try stream.expect("]")
        return options
    }

    mutating func reservedNames() throws(ProtoCompileError) -> [String] {
        var names: [String] = []
        repeat {
            if stream.current.kind == .string {
                names.append(String(decoding: try stream.strings("a name"), as: UTF8.self))
            } else {
                names.append(try stream.identifier("a name"))
            }
        } while stream.accept(",")
        try stream.expect(";")
        return names
    }

    /// `extend Type {`
    mutating func openExtend(scope: Int?) throws(ProtoCompileError) {
        stream.take()
        let extendee = try stream.fullIdentifier("a message to extend")
        try push(.extend(scope: scope, extendee: extendee))
    }

    mutating func extendStatement(scope: Int?, extendee: String) throws(ProtoCompileError) {
        try field(in: scope, oneof: nil, extendee: extendee)
    }
}
