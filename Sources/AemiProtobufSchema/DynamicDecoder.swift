import AemiProtobufCore

/// One ``DynamicSchema/decode(_:as:limits:)``, without recursion. Each nested message is a node; reading a message's bytes is
/// a job, and jobs run first in, first out. A message's fields are read whole, its nested messages queued, so a node is always
/// created after its parent and every job of a node runs in the order its bytes came. A singular message field that occurs again
/// queues another job on the same node, which is protobuf's merge. Nodes are then folded into their parents, last first, so each
/// is complete when it is folded.
struct DynamicDecoder {
    /// Where a node's message goes in its parent.
    struct Link {
        let parent: Int
        let field: Int32
        let slot: DynamicSlot
    }

    struct Node {
        let type: DynamicMessageType
        let depth: Int
        /// `nil` for the root, and for a node a later oneof member or map entry replaced.
        var parent: Link?
        var fields = DynamicFields()
        /// The node of each singular message field, which a later occurrence merges into.
        var children: [Int32: Int] = [:]
        /// The node of each message value of each map field, by key.
        var mapChildren: [Int32: [DynamicValue: Int]] = [:]
    }

    struct Job {
        let node: Int
        let range: Range<Int>
    }

    let schema: DynamicSchema
    let bytes: [UInt8]
    let limits: WireLimits
    var nodes: [Node]
    var jobs: [Job]

    init(schema: DynamicSchema, bytes: [UInt8], limits: WireLimits, root: DynamicMessageType) {
        self.schema = schema
        self.bytes = bytes
        self.limits = limits
        nodes = [Node(type: root, depth: 0)]
        jobs = [Job(node: 0, range: 0 ..< bytes.count)]
    }

    mutating func run() throws(WireError) -> DynamicMessage {
        var next = 0
        while next < jobs.count {
            let job = jobs[next]
            next += 1
            try WireReader.withReader(over: bytes, in: job.range, depth: nodes[job.node].depth, limits: limits) {
                (reader) throws(WireError) in
                while let tag = try reader.nextTag() { try self.read(tag, from: &reader, into: job.node) }
            }
        }
        try checkRequired()
        return fold()
    }

    /// Refuses a message, the root or one still attached to it, that lacks a required field.
    private func checkRequired() throws(WireError) {
        var attached = [Bool](repeating: false, count: nodes.count)
        for index in nodes.indices {
            let node = nodes[index]
            attached[index] = index == 0 || node.parent.map { attached[$0.parent] } ?? false
            guard attached[index] else { continue }
            for field in node.type.requiredFields
            where node.fields.values[field.number] == nil && node.children[field.number] == nil {
                throw .missingRequired(path: node.type.name + "." + field.name)
            }
        }
    }

    /// Folds every attached node into its parent, the last created first, and returns the root.
    private mutating func fold() -> DynamicMessage {
        var index = nodes.count - 1
        while index > 0 {
            if let link = nodes[index].parent {
                let message = nodes[index].fields.take(typeName: nodes[index].type.name)
                nodes[link.parent].fields.place(message, field: link.field, slot: link.slot)
            }
            index -= 1
        }
        return nodes[0].fields.take(typeName: nodes[0].type.name)
    }
}
