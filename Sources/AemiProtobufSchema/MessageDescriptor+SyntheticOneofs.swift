extension MessageDescriptor {
    /// Gives each proto3 `optional` field its own synthetic oneof `_name`, after the declared oneofs, as protoc does.
    /// - Complexity: O(fields).
    mutating func addSyntheticOneofs() {
        for index in fields.indices where fields[index].proto3Optional {
            fields[index].oneofIndex = Int32(oneofs.count)
            oneofs.append(OneofDescriptor(name: "_" + fields[index].name))
        }
    }
}
