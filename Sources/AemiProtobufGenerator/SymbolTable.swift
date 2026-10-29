import AemiProtobufSchema

/// Every message and enumeration of a descriptor set by its full name (`.package.Outer.Inner`), with its Swift name, its file
/// and the features in force for it.
struct SymbolTable {
    enum Declaration {
        case message(MessageDescriptor)
        case enumeration(EnumDescriptor)
    }

    struct Symbol {
        let fullName: String
        let swiftName: String
        let declaration: Declaration
        let file: FileDescriptor
        let features: ResolvedFeatures
    }

    private(set) var symbols: [String: Symbol] = [:]

    init(_ set: FileDescriptorSet) {
        for file in set.files {
            let features = ResolvedFeatures.of(file)
            let scope = file.package.isEmpty ? "" : "." + file.package
            let prefix = SwiftNaming.prefix(package: file.package)
            for message in file.messages {
                addMessage(message, scope: scope, swift: prefix + message.name, file: file, features: features)
            }
            for enumeration in file.enums {
                addEnumeration(
                    enumeration, scope: scope, swift: prefix + enumeration.name, file: file, features: features)
            }
        }
    }

    private mutating func addMessage(
        _ message: MessageDescriptor, scope: String, swift: String, file: FileDescriptor, features: ResolvedFeatures
    ) {
        // Iterative, as the repository allows no recursion (ADR-0003).
        var pending = [(message, scope, swift, features)]
        while let (message, scope, swift, inherited) = pending.popLast() {
            let fullName = scope + "." + message.name
            let features = inherited.merged(message.features)
            symbols[fullName] = Symbol(
                fullName: fullName, swiftName: swift, declaration: .message(message), file: file, features: features)
            for nested in message.nestedMessages {
                pending.append((nested, fullName, swift + "." + nested.name, features))
            }
            for enumeration in message.nestedEnums {
                addEnumeration(
                    enumeration, scope: fullName, swift: swift + "." + enumeration.name, file: file, features: features)
            }
        }
    }

    private mutating func addEnumeration(
        _ enumeration: EnumDescriptor, scope: String, swift: String, file: FileDescriptor, features: ResolvedFeatures
    ) {
        let fullName = scope + "." + enumeration.name
        symbols[fullName] = Symbol(
            fullName: fullName, swiftName: swift, declaration: .enumeration(enumeration), file: file,
            features: features.merged(enumeration.features))
    }

    subscript(_ fullName: String) -> Symbol? { symbols[fullName] }

    func message(_ fullName: String) -> MessageDescriptor? {
        if case .message(let message)? = symbols[fullName]?.declaration { return message }
        return nil
    }

    /// Whether an enumeration keeps numbers it has no case for.
    func isOpen(_ fullName: String) -> Bool { symbols[fullName]?.features.enumType == 1 }
}
