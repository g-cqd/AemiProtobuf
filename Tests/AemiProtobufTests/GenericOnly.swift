import AemiProtobuf

/// Hides the fast path, so the generic `Codable` path encodes ``TreeNode``.
struct GenericOnly: Encodable {
    let tree: TreeNode
    init(_ tree: TreeNode) { self.tree = tree }
    func encode(to encoder: any Encoder) throws { try tree.encode(to: encoder) }
}
