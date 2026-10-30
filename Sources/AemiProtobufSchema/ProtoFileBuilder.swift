/// Assembles a ``FileDescriptor`` from a parsed file whose names are resolved and options interpreted: fields, enumerations and
/// extensions go to their messages, then messages are folded into their parents, the last declared first, so every message is
/// complete before it is placed and the declaration order is kept.
enum ProtoFileBuilder {
    static func build(_ parsed: ParsedFile) -> FileDescriptor {
        var messages = parsed.messages.map { message -> MessageDescriptor in
            var descriptor = message.descriptor
            descriptor.fields = message.fields.map(\.descriptor)
            descriptor.addSyntheticOneofs()
            return descriptor
        }
        var file = FileDescriptor(name: parsed.name, package: parsed.package, syntax: parsed.syntax)
        file.dependencies = parsed.dependencies
        file.publicDependencies = parsed.publicDependencies
        file.weakDependencies = parsed.weakDependencies
        file.edition = parsed.edition
        file.options = parsed.optionBytes
        for enumeration in parsed.enums {
            if let parent = enumeration.parent {
                messages[parent].nestedEnums.append(enumeration.descriptor)
            } else {
                file.enums.append(enumeration.descriptor)
            }
        }
        for field in parsed.extensions {
            if let scope = field.scope {
                messages[scope].extensions.append(field.descriptor)
            } else {
                file.extensions.append(field.descriptor)
            }
        }
        var topLevel: [MessageDescriptor] = []
        for index in messages.indices.reversed() {
            if let parent = parsed.messages[index].parent {
                messages[parent].nestedMessages.insert(messages[index], at: 0)
            } else {
                topLevel.insert(messages[index], at: 0)
            }
        }
        file.messages = topLevel
        file.services = parsed.services.map(\.descriptor)
        return file
    }
}
