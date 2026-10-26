extension FileDescriptorSet {
    /// Checks every message, nested ones included, with an explicit work list (no recursion).
    /// - Complexity: O(messages + fields).
    func checkReferences() throws(DescriptorError) {
        var pending = files.flatMap(\.messages)
        while let message = pending.popLast() {
            for field in message.fields {
                guard let index = field.oneofIndex else { continue }
                guard index >= 0, Int(index) < message.oneofs.count else {
                    throw .oneofIndexOutOfRange(message: message.name, field: field.name, index: index)
                }
            }
            pending.append(contentsOf: message.nestedMessages)
        }
    }
}
