/// The state of one ``ProtoPrinter/print(_:)``: lines written so far and a stack of what is still to be written. A message
/// pushes its closing brace and its body, last first; nested messages are expanded when they come off.
struct ProtoSourceWriter {
    enum Work {
        case line(String, indent: Int)
        /// A message's header line (`message Name {` or a group's), its body, and its closing brace.
        case message(MessageDescriptor, scope: String, header: String, indent: Int)
    }

    let file: FileDescriptor
    let schema: DynamicSchema
    var lines: [String] = []
    var stack: [Work] = []

    init(file: FileDescriptor, schema: DynamicSchema) {
        self.file = file
        self.schema = schema
    }

    var isProto3: Bool { file.syntax == "proto3" }
    var isEditions: Bool { file.syntax == "editions" }

    mutating func run() -> String {
        if isEditions {
            lines.append("edition = \"\(file.edition == 1001 ? "2024" : "2023")\";")
        } else {
            lines.append("syntax = \"\(isProto3 ? "proto3" : "proto2")\";")
        }
        if !file.package.isEmpty { lines.append("package \(file.package);") }
        for (index, dependency) in file.dependencies.enumerated() {
            let kind =
                file.publicDependencies.contains(Int32(index))
                ? "public " : file.weakDependencies.contains(Int32(index)) ? "weak " : ""
            lines.append("import \(kind)\(ProtoLiteral.quoted(Array(dependency.utf8), keepUTF8: true));")
        }
        for (name, value) in optionEntries(file.options, "FileOptions") { lines.append("option \(name) = \(value);") }
        var body: [Work] = []
        for enumeration in file.enums { body += enumLines(enumeration, indent: 0) }
        body += members(fields: [], extensions: file.extensions, nested: file.messages, scope: file.package, indent: 0)
        for service in file.services { body += serviceLines(service, indent: 0) }
        stack = body.reversed()
        while let work = stack.popLast() {
            switch work {
                case .line(let text, let indent): lines.append(String(repeating: "  ", count: indent) + text)
                case .message(let message, let scope, let header, let indent):
                    lines.append(String(repeating: "  ", count: indent) + header)
                    let name = scope.isEmpty ? message.name : scope + "." + message.name
                    var inner = messageBody(message, scope: name, indent: indent + 1)
                    inner.append(.line("}", indent: indent))
                    stack.append(contentsOf: inner.reversed())
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// A message's statements: options, enumerations, fields with their nested messages, extension ranges, reservations.
    private func messageBody(_ message: MessageDescriptor, scope: String, indent: Int) -> [Work] {
        var body: [Work] = optionEntries(message.options, "MessageOptions")
            .map { .line("option \($0) = \($1);", indent: indent) }
        for enumeration in message.nestedEnums { body += enumLines(enumeration, indent: indent) }
        body += members(
            fields: message.fields, extensions: message.extensions, nested: message.nestedMessages, scope: scope,
            indent: indent, oneofs: message.oneofs)
        for range in message.extensionRanges {
            let suffix = bracketed(optionEntries(range.options, "ExtensionRangeOptions"))
            body.append(.line("extensions \(rangeText(range, endIncluded: false))\(suffix);", indent: indent))
        }
        for range in message.reservedRanges {
            body.append(.line("reserved \(rangeText(range, endIncluded: false));", indent: indent))
        }
        body += reservedNameLines(message.reservedNames, indent: indent)
        return body
    }

    func reservedNameLines(_ names: [String], indent: Int) -> [Work] {
        names.map {
            .line(
                "reserved " + (isEditions ? $0 : ProtoLiteral.quoted(Array($0.utf8), keepUTF8: true)) + ";",
                indent: indent)
        }
    }

    private func enumLines(_ enumeration: EnumDescriptor, indent: Int) -> [Work] {
        var lines: [Work] = [.line("enum \(enumeration.name) {", indent: indent)]
        lines += optionLines(enumeration.options, "EnumOptions", indent: indent + 1)
        for value in enumeration.values {
            let suffix = bracketed(optionEntries(value.options, "EnumValueOptions"))
            lines.append(.line("\(value.name) = \(value.number)\(suffix);", indent: indent + 1))
        }
        for range in enumeration.reservedRanges {
            lines.append(.line("reserved \(rangeText(range, endIncluded: true));", indent: indent + 1))
        }
        lines += reservedNameLines(enumeration.reservedNames, indent: indent + 1)
        lines.append(.line("}", indent: indent))
        return lines
    }

    private func serviceLines(_ service: ServiceDescriptor, indent: Int) -> [Work] {
        var lines: [Work] = [.line("service \(service.name) {", indent: indent)]
        lines += optionLines(service.options, "ServiceOptions", indent: indent + 1)
        for method in service.methods {
            let input = (method.clientStreaming == true ? "stream " : "") + method.inputType
            let output = (method.serverStreaming == true ? "stream " : "") + method.outputType
            let head = "rpc \(method.name)(\(input)) returns (\(output))"
            guard let options = method.options else {
                lines.append(.line(head + ";", indent: indent + 1))
                continue
            }
            lines.append(.line(head + " {", indent: indent + 1))
            lines += optionLines(options, "MethodOptions", indent: indent + 2)
            lines.append(.line("}", indent: indent + 1))
        }
        lines.append(.line("}", indent: indent))
        return lines
    }

    /// `option name = value;` lines.
    func optionLines(_ bytes: [UInt8]?, _ typeName: String, indent: Int) -> [Work] {
        optionEntries(bytes, typeName).map { .line("option \($0) = \($1);", indent: indent) }
    }

    /// ` [name = value, …]`, or nothing.
    func bracketed(_ entries: [(String, String)]) -> String {
        entries.isEmpty ? "" : " [" + entries.map { "\($0) = \($1)" }.joined(separator: ", ") + "]"
    }

    /// `start`, `start to end`, or `start to max`: a message's end is exclusive, an enumeration's inclusive.
    private func rangeText(_ range: DescriptorRange, endIncluded: Bool) -> String {
        let start = range.start ?? 0
        let end = endIncluded ? range.end ?? start : (range.end ?? 1) - 1
        let max = endIncluded ? end == Int32.max : end >= Int32(FieldNumberLimit.maximum)
        return max ? "\(start) to max" : end == start ? "\(start)" : "\(start) to \(end)"
    }
}
