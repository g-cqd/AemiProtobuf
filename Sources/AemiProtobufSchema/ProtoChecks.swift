/// The checks protoc makes once names are resolved: numbers used twice, numbers and names a message or enumeration reserved,
/// the range protobuf keeps for itself, an open enumeration whose first value is not zero, and extensions outside their
/// extendee's extension ranges.
enum ProtoChecks {
    static func check(_ files: [FileDescriptor], parsed: [ParsedFile]) throws(ProtoCompileError) {
        var messages: [String: MessageDescriptor] = [:]
        for file in parsed { for message in file.messages { messages[message.fullName] = message.descriptor } }
        for (file, built) in zip(parsed, files) {
            for message in file.messages { try check(message, file: file.name) }
            let features = ResolvedFeatures.of(built)
            for enumeration in file.enums { try check(enumeration, file: file, features: features) }
            for field in file.extensions {
                guard let extendee = messages[String(field.descriptor.extendee.dropFirst())] else { continue }
                let number = field.descriptor.number
                guard extendee.extensionRanges.contains(where: { number >= ($0.start ?? 0) && number < ($0.end ?? 0) })
                else {
                    throw ProtoCompileError(
                        file: file.name, line: field.line, column: field.column,
                        message:
                            "\"\(field.descriptor.extendee.dropFirst())\" does not declare \(number) as an extension number."
                    )
                }
            }
        }
    }

    private static func check(_ message: ParsedMessage, file: String) throws(ProtoCompileError) {
        var used: [Int32: String] = [:]
        let reservedNames = Set(message.descriptor.reservedNames)
        for field in message.fields {
            let number = field.descriptor.number
            func fail(_ text: String) -> ProtoCompileError { error(file, field.line, field.column, text) }
            if let other = used[number] {
                throw fail(
                    "Field number \(number) has already been used in \"\(message.fullName)\" by field \"\(other)\".")
            }
            used[number] = field.descriptor.name
            if (19_000 ... 19_999).contains(number) {
                throw fail(
                    "Field numbers 19000 through 19999 are reserved for the protocol buffer library implementation.")
            }
            if message.descriptor.reservedRanges.contains(where: { number >= ($0.start ?? 0) && number < ($0.end ?? 0) }
            ) {
                throw fail("Field \"\(field.descriptor.name)\" uses reserved number \(number).")
            }
            if reservedNames.contains(field.descriptor.name) {
                throw fail("Field name \"\(field.descriptor.name)\" is reserved.")
            }
            if message.descriptor.extensionRanges.contains(where: {
                number >= ($0.start ?? 0) && number < ($0.end ?? 0)
            }) {
                throw fail("Extension range overlaps field \"\(field.descriptor.name)\" (\(number)).")
            }
        }
    }

    private static func check(_ enumeration: ParsedEnum, file: ParsedFile, features: ResolvedFeatures)
        throws(ProtoCompileError)
    {
        func fail(_ text: String) -> ProtoCompileError { error(file.name, enumeration.line, enumeration.column, text) }
        let descriptor = enumeration.descriptor
        let open =
            file.resolvedSyntax == "proto3"
            || file.syntax == "editions" && features.merged(descriptor.features).enumType == 1
        if open, let first = descriptor.values.first, first.number != 0 {
            throw fail("The first enum value must be zero for open enums.")
        }
        var used: [Int32: String] = [:]
        let reservedNames = Set(descriptor.reservedNames)
        for value in descriptor.values {
            if let other = used[value.number], !descriptor.allowAlias {
                throw fail("\"\(value.name)\" uses the same enum value as \"\(other)\". Set allow_alias to allow it.")
            }
            used[value.number] = used[value.number] ?? value.name
            if descriptor.reservedRanges.contains(where: {
                value.number >= ($0.start ?? 0) && value.number <= ($0.end ?? 0)
            }) {
                throw fail("Enum value \"\(value.name)\" uses reserved number \(value.number).")
            }
            if reservedNames.contains(value.name) { throw fail("Enum value \"\(value.name)\" is reserved.") }
        }
    }

    /// Whether `number` lies in one of `ranges` (a message's end excluded, an enumeration's included).
    private static func contains(_ ranges: [DescriptorRange], _ number: Int32, endIncluded: Bool = false) -> Bool {
        ranges.contains {
            number >= ($0.start ?? 0) && (endIncluded ? number <= ($0.end ?? 0) : number < ($0.end ?? 0))
        }
    }

    private static func error(_ file: String, _ line: Int, _ column: Int, _ text: String) -> ProtoCompileError {
        ProtoCompileError(file: file, line: line, column: column, message: text)
    }
}
