import AemiProtobuf
import AemiProtobufCore
import Testing

/// Roadmap 0024: a message that holds itself, through `@Indirect`, with value semantics and the depth limit.
@Suite struct IndirectTests {
    @Test func `a chain at the depth limit round-trips`() throws {
        let chain = TreeNode.chain(98)
        let bytes = try ProtobufEncoder().encodeToBytes(chain)
        #expect(try ProtobufDecoder().decode(TreeNode.self, fromBytes: bytes) == chain)
    }

    @Test func `a chain past the depth limit is refused, encoding and decoding`() throws {
        let deep = TreeNode.chain(101)
        #expect(throws: (any Error).self) { try ProtobufEncoder().encodeToBytes(deep) }
        let bytes = try ProtobufEncoder(limits: WireLimits(maxDepth: 200)).encodeToBytes(deep)
        #expect(throws: (any Error).self) { try ProtobufDecoder().decode(TreeNode.self, fromBytes: bytes) }
        #expect(try ProtobufDecoder(limits: WireLimits(maxDepth: 200)).decode(TreeNode.self, fromBytes: bytes) == deep)
    }

    @Test func `a copy is a value: changing it leaves the original`() {
        let original = TreeNode.chain(3)
        var copy = original
        copy.child?.child?.value = 42
        #expect(original.child?.child?.value == 2)
        #expect(copy.child?.child?.value == 42)
        #expect(copy != original)
    }

    @Test func `an indirect message given twice merges`() throws {
        // child {value: 1} then child {children {value: 2}}
        let bytes: [UInt8] = [0x12, 0x02, 0x08, 0x01, 0x12, 0x04, 0x1A, 0x02, 0x08, 0x02]
        let decoded = try ProtobufDecoder().decode(TreeNode.self, fromBytes: bytes)
        #expect(decoded.child == TreeNode(value: 1, children: [TreeNode(value: 2)]))
    }

    @Test func `the generic coders see the wrapped value`() throws {
        let tree = TreeNode(value: 1, child: TreeNode(value: 2), children: [TreeNode(value: 3)])
        let fast = try ProtobufEncoder().encodeToBytes(tree)
        #expect(try ProtobufEncoder().encode(GenericOnly(tree)).elementsEqual(fast))
    }
}

/// Hides the fast path, so the generic `Codable` path encodes ``TreeNode``.
private struct GenericOnly: Encodable {
    let tree: TreeNode
    init(_ tree: TreeNode) { self.tree = tree }
    func encode(to encoder: any Encoder) throws { try tree.encode(to: encoder) }
}
