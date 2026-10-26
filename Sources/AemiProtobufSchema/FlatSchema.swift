/// A descriptor set with every message and enum, nested ones included, under its fully qualified name.
struct FlatSchema {
    var messages: [String: MessageDescriptor] = [:]
    var enums: [String: EnumDescriptor] = [:]

    /// Walks the set with an explicit work list (no recursion).
    /// - Complexity: O(messages + enums).
    init(_ set: FileDescriptorSet) {
        var pending: [(String, MessageDescriptor)] = []
        for file in set.files {
            let scope = file.package.isEmpty ? "" : file.package + "."
            pending.append(contentsOf: file.messages.map { (scope + $0.name, $0) })
            for e in file.enums { enums[scope + e.name] = e }
        }
        while let (name, message) = pending.popLast() {
            messages[name] = message
            pending.append(contentsOf: message.nestedMessages.map { (name + "." + $0.name, $0) })
            for e in message.nestedEnums { enums[name + "." + e.name] = e }
        }
    }
}
