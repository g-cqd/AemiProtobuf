extension ProtoFileParser {
    /// `enum Name {`
    mutating func openEnum(parent: Int?) throws(ProtoCompileError) {
        let token = stream.take()
        let name = try stream.identifier("an enum name")
        file.enums.append(
            ParsedEnum(
                descriptor: EnumDescriptor(name: name), parent: parent, fullName: fullName(name, in: parent),
                line: token.line, column: token.column))
        try push(.enumeration(file.enums.count - 1))
    }

    /// An option, a reservation, or `NAME = number [options];`.
    mutating func enumStatement(_ index: Int) throws(ProtoCompileError) {
        let token = stream.current
        if token.isIdentifier("option") {
            file.enums[index].options.append(try optionStatement())
            return
        }
        if token.isIdentifier("reserved"), stream.peek().kind != .symbol || stream.peek().isSymbol("-") {
            let (ranges, names) = try reservation(min: Int64(Int32.min), max: Int64(Int32.max), endIncluded: true)
            file.enums[index].descriptor.reservedRanges += ranges
            file.enums[index].descriptor.reservedNames += names
            return
        }
        let name = try stream.identifier("an enum value name")
        try stream.expect("=")
        let numberToken = stream.current
        let number = try stream.integer("an enum value number")
        guard number >= Int64(Int32.min), number <= Int64(Int32.max) else {
            throw stream.error("integer out of range", at: numberToken)
        }
        let options = try bracketOptions()
        try stream.expect(";")
        file.enums[index].descriptor.values.append(EnumValueDescriptor(name: name, number: Int32(number)))
        file.enums[index].valueOptions.append(options)
    }

    /// `service Name {`
    mutating func openService() throws(ProtoCompileError) {
        let token = stream.take()
        let name = try stream.identifier("a service name")
        var descriptor = ServiceDescriptor()
        descriptor.name = name
        file.services.append(
            ParsedService(
                descriptor: descriptor, fullName: fullName(name, in: nil), line: token.line, column: token.column))
        try push(.service(file.services.count - 1))
    }

    /// An option, or `rpc Name ([stream] In) returns ([stream] Out)` followed by `;` or an options body.
    mutating func serviceStatement(_ index: Int) throws(ProtoCompileError) {
        if stream.current.isIdentifier("option") {
            file.services[index].options.append(try optionStatement())
            return
        }
        guard stream.acceptWord("rpc") else { throw stream.error("expected \"rpc\"") }
        var method = MethodDescriptor()
        method.name = try stream.identifier("a method name")
        try stream.expect("(")
        method.clientStreaming = streamed()
        method.inputType = try stream.fullIdentifier("an input type")
        try stream.expect(")")
        guard stream.acceptWord("returns") else { throw stream.error("expected \"returns\"") }
        try stream.expect("(")
        method.serverStreaming = streamed()
        method.outputType = try stream.fullIdentifier("an output type")
        try stream.expect(")")
        file.services[index].descriptor.methods.append(method)
        file.services[index].methodOptions.append([])
        if stream.current.isSymbol("{") {
            file.services[index].methodBodies.insert(file.services[index].descriptor.methods.count - 1)
            try push(.method(service: index, index: file.services[index].descriptor.methods.count - 1))
        } else {
            try stream.expect(";")
        }
    }

    /// `true` after taking `stream` before a type name; `nil` (protoc writes nothing) otherwise.
    private mutating func streamed() -> Bool? {
        guard stream.current.isIdentifier("stream"), stream.peek().kind == .identifier || stream.peek().isSymbol(".")
        else {
            return nil
        }
        stream.take()
        return true
    }
}
