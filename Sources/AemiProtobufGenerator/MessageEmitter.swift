import AemiProtobufSchema

/// A message as a `@ProtoMessage` struct: its fields in field-number order (so it writes the bytes C++ writes), each oneof as a
/// `@ProtoOneof` enumeration placed at its first member's number, then its nested types.
struct MessageEmitter {
    let symbols: SymbolTable
    let planner: FieldPlanner
    /// Same-file extensions, by the full name of the message they extend: written as fields of it.
    let extensions: [String: [FieldDescriptor]]
    let options: GeneratorOptions

    private var access: String { options.visibility == .public ? "public " : "" }

    /// A message being written: what comes before its nested messages, what they become, and which are left.
    private struct Frame {
        var head: [String]
        var nested: [[String]]
        var children: [String]
        var next = 0
    }

    /// The struct for `fullName` with every nested message inside it. Iterative (the repository allows no recursion): a stack
    /// of frames, each finished when its last child is.
    func emit(_ fullName: String, name: String) throws(GeneratorError) -> [String] {
        var stack = [try frame(fullName, name: name)]
        var finished: [String] = []
        while var top = stack.popLast() {
            if !finished.isEmpty {
                top.nested.append(finished)
                finished = []
            }
            if top.next < top.children.count {
                let child = top.children[top.next]
                top.next += 1
                stack.append(top)
                stack.append(try frame(child, name: nil))
                continue
            }
            finished = top.head
            for declaration in top.nested { finished += [""] + declaration }
            finished.append("}")
        }
        return finished
    }

    private func frame(_ fullName: String, name declaredName: String?) throws(GeneratorError) -> Frame {
        guard let symbol = symbols[fullName], case .message(let message) = symbol.declaration else {
            throw .unknownType(fullName)
        }
        let attribute = options.discardsUnknownFields ? "@ProtoMessage(unknownFields: .discard)" : "@ProtoMessage"
        var lines = [attribute, "\(access)struct \(declaredName ?? message.name): Equatable, Sendable {"]
        var members: [(number: Int32, line: String)] = []
        var used: Set<String> = []
        func name(_ field: String) -> String {
            var candidate = SwiftNaming.property(field)
            while used.contains(candidate) { candidate += "_" }
            used.insert(candidate)
            return candidate
        }
        let fields = message.fields + (extensions[fullName] ?? [])
        for field in fields where !isInRealOneof(field) {
            let declaration = try planner.declaration(
                field, owner: fullName, features: symbol.features, name: name(field.name), access: access)
            members.append((field.number, declaration))
        }
        var nested: [[String]] = []
        for (index, oneof) in message.oneofs.enumerated() {
            let memberFields = message.fields.filter { $0.oneofIndex == Int32(index) && !$0.proto3Optional }
            guard let first = memberFields.map(\.number).min() else { continue }
            let typeName = "OneOf_" + SwiftNaming.camel(oneof.name, upper: true)
            members.append((first, "@ProtoOneofField \(access)var \(name(oneof.name)): \(typeName)? = nil"))
            nested.append(try oneofEnum(typeName, memberFields, owner: fullName, features: symbol.features))
        }
        for enumeration in message.nestedEnums {
            let open = symbols.isOpen(fullName + "." + enumeration.name)
            nested.append(EnumEmitter.emit(enumeration, open: open, access: access))
        }
        for member in members.sorted(by: { $0.number < $1.number }) { lines.append(member.line) }
        lines += try defaultAccessors(fields)
        if options.visibility == .public { lines += ["", "public init() {}"] }
        let children = message.nestedMessages.filter { !$0.isMapEntry }.map { fullName + "." + $0.name }
        return Frame(head: lines, nested: nested, children: children)
    }

    /// A field in a declared oneof; a proto3 `optional` sits in a synthetic one and is a plain optional field.
    private func isInRealOneof(_ field: FieldDescriptor) -> Bool {
        field.oneofIndex != nil && !field.proto3Optional
    }

    private func oneofEnum(
        _ typeName: String, _ fields: [FieldDescriptor], owner: String, features: ResolvedFeatures
    ) throws(GeneratorError) -> [String] {
        var cases: [String] = []
        var indirect = false
        var used: Set<String> = []
        for field in fields.sorted(by: { $0.number < $1.number }) {
            let delimited = planner.isDelimited(field, features.merged(field.features))
            let (type, kind) = try planner.scalar(field, delimited: delimited)
            if field.type == .message || field.type == .group,
                planner.recursion.needsIndirection(owner: owner, target: field.typeName)
            {
                indirect = true
            }
            var caseName = SwiftNaming.property(field.name)
            while used.contains(caseName) { caseName += "_" }
            used.insert(caseName)
            let arguments = ["\(field.number)"] + (kind.map { [$0] } ?? [])
            cases.append("@ProtoField(\(arguments.joined(separator: ", "))) case \(caseName)(\(type))")
        }
        return ["@ProtoOneof", "\(access)\(indirect ? "indirect " : "")enum \(typeName): Equatable, Sendable {"]
            + cases + ["}"]
    }

    /// `var nameOrDefault`, for each field with a proto2 `[default = …]`: what a getter returns when the field is absent.
    private func defaultAccessors(_ fields: [FieldDescriptor]) throws(GeneratorError) -> [String] {
        var lines: [String] = []
        for field in fields where field.label != .repeated {
            guard let value = field.defaultValue,
                let literal = try DefaultLiteral.swift(value, for: field, symbols: symbols)
            else { continue }
            let (type, _) = try planner.scalar(field, delimited: false)
            let property = SwiftNaming.property(field.name)
            let plain = property.filter { $0 != "`" }
            lines.append("\(access)var \(plain)OrDefault: \(type) { \(property) ?? \(literal) }")
        }
        return lines.isEmpty ? [] : [""] + lines
    }
}
