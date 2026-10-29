import AemiProtobuf

/// A message that holds itself, as `TestAllTypesProto3.recursive_message` does: through `@Indirect`, and through an array.
@ProtoMessage
struct TreeNode: Equatable {
    @ProtoField(1) var value: Int32 = 0
    @ProtoField(2) @Indirect var child: TreeNode? = nil
    @ProtoField(3) var children: [TreeNode] = []

    /// A chain `depth` messages deep below the root.
    static func chain(_ depth: Int) -> TreeNode {
        var node = TreeNode(value: Int32(depth))
        for level in stride(from: depth - 1, through: 0, by: -1) { node = TreeNode(value: Int32(level), child: node) }
        return node
    }
}
