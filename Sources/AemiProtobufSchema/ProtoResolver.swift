/// Resolves the names a parsed file writes: field types (setting message or enumeration), extendees, and method types.
struct ProtoResolver {
    let symbols: ProtoSymbols

    /// Declares everything `file` declares.
    static func declare(_ file: ParsedFile, in symbols: inout ProtoSymbols) throws(ProtoCompileError) {
        try symbols.addPackage(file.package, file: file.name)
        let name = file.name
        for message in file.messages {
            try symbols.add(message.fullName, .message, file: name, line: message.line, column: message.column)
            for field in message.fields {
                try symbols.add(
                    message.fullName + "." + field.descriptor.name, .field, file: name, line: field.line,
                    column: field.column)
            }
            for oneof in message.descriptor.oneofs {
                try symbols.add(
                    message.fullName + "." + oneof.name, .oneof, file: name, line: message.line, column: message.column)
            }
        }
        for enumeration in file.enums {
            try symbols.add(
                enumeration.fullName, .enumeration, file: name, line: enumeration.line, column: enumeration.column)
            let scope = file.scope(of: enumeration.parent)
            for value in enumeration.descriptor.values {
                try symbols.add(
                    scope.isEmpty ? value.name : scope + "." + value.name, .enumValue, file: name,
                    line: enumeration.line, column: enumeration.column)
            }
        }
        for field in file.extensions {
            let scope = file.scope(of: field.scope)
            try symbols.add(
                scope.isEmpty ? field.descriptor.name : scope + "." + field.descriptor.name, .extension,
                file: name, line: field.line, column: field.column)
        }
        for service in file.services {
            try symbols.add(service.fullName, .service, file: name, line: service.line, column: service.column)
            for method in service.descriptor.methods {
                try symbols.add(
                    service.fullName + "." + method.name, .method, file: name, line: service.line,
                    column: service.column)
            }
        }
    }

    func resolve(_ file: inout ParsedFile) throws(ProtoCompileError) {
        for index in file.messages.indices {
            let scope = file.messages[index].fullName
            for position in file.messages[index].fields.indices {
                try resolveType(&file.messages[index].fields[position], scope: scope, file: file.name)
            }
        }
        for index in file.extensions.indices {
            let scope = file.scope(of: file.extensions[index].scope)
            let field = file.extensions[index]
            guard let extendee = symbols.resolve(field.descriptor.extendee, in: scope, accept: { $0 == .message })
            else {
                throw error(file.name, field, "\"\(field.descriptor.extendee)\" is not defined.")
            }
            file.extensions[index].descriptor.extendee = "." + extendee
            try resolveType(&file.extensions[index], scope: scope, file: file.name)
        }
        for index in file.services.indices {
            let service = file.services[index]
            for position in service.descriptor.methods.indices {
                let method = service.descriptor.methods[position]
                for (written, isInput) in [(method.inputType, true), (method.outputType, false)] {
                    guard let found = symbols.resolve(written, in: file.package, accept: { $0 == .message }) else {
                        throw ProtoCompileError(
                            file: file.name, line: service.line, column: service.column,
                            message: "\"\(written)\" is not defined.")
                    }
                    if isInput {
                        file.services[index].descriptor.methods[position].inputType = "." + found
                    } else {
                        file.services[index].descriptor.methods[position].outputType = "." + found
                    }
                }
            }
        }
    }

    private func resolveType(_ field: inout ParsedField, scope: String, file: String) throws(ProtoCompileError) {
        guard field.namedType else { return }
        let written = field.descriptor.typeName
        guard let found = symbols.resolve(written, in: scope, accept: { $0.isType }), let kind = symbols.kind(of: found)
        else {
            throw error(file, field, "\"\(written)\" is not defined.")
        }
        field.descriptor.typeName = "." + found
        if field.descriptor.type != .group { field.descriptor.type = kind == .enumeration ? .enum : .message }
    }

    private func error(_ file: String, _ field: ParsedField, _ message: String) -> ProtoCompileError {
        ProtoCompileError(file: file, line: field.line, column: field.column, message: message)
    }
}
