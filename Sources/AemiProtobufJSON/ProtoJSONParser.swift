import AemiJSONCore
import AemiProtobufSchema

/// One JSON read, without recursion: as ``DynamicSchema`` decodes binary. Each nested message is a node; reading a node's JSON
/// value is a job; jobs run first in, first out, and nodes are folded into their parents last first. An `Any`'s message is
/// folded in as its binary encoding.
struct ProtoJSONParser {
    struct Link {
        let parent: Int
        let field: Int32
        let slot: Slot
    }

    enum Slot {
        case place(DynamicSlot)
        /// The message an `Any` holds, encoded into its `value` beside `type_url`.
        case anyValue(typeURL: String)
    }

    struct Node {
        let type: DynamicMessageType
        let depth: Int
        /// The name of the field the node is in (empty for the root): with the parent links, the path errors name.
        let name: String
        var parent: Link?
        var fields = DynamicFields()
    }

    struct Job {
        let node: Int
        let json: JSON
        /// An `Any`'s object read as its message: the `@type` member is not a field.
        let skipsType: Bool
    }

    let schema: DynamicSchema
    let options: ProtoJSONCoder.Options
    let scalars: ProtoJSONScalars
    var nodes: [Node] = []
    var jobs: [Job] = []

    init(schema: DynamicSchema, options: ProtoJSONCoder.Options) {
        self.schema = schema
        self.options = options
        scalars = ProtoJSONScalars(schema: schema, ignoreUnknownFields: options.ignoreUnknownFields)
    }

    mutating func run(_ json: JSON, as type: DynamicMessageType) throws(ProtoJSONError) -> DynamicMessage {
        nodes = [Node(type: type, depth: 0, name: type.name)]
        jobs = [Job(node: 0, json: json, skipsType: false)]
        var next = 0
        while next < jobs.count {
            let job = jobs[next]
            next += 1
            do throws(ProtoJSONError) {
                if !job.skipsType, let known = WellKnownType(nodes[job.node].type.name) {
                    try readWellKnown(known, job)
                } else {
                    guard case .object = JSONShape(job.json) else { throw .invalid("expected an object", path: "") }
                    try readMembers(job)
                }
            } catch {
                throw locate(error, job.node, nil)
            }
        }
        return try fold()
    }

    /// Creates the node for a message of the type `typeName` names and queues its JSON value.
    @discardableResult
    mutating func spawn(_ typeName: String?, _ json: JSON, _ link: Link, name: String, skipsType: Bool = false)
        throws(ProtoJSONError) -> Int
    {
        guard let typeName, let type = schema.messageType(named: typeName) else { throw .unknownType(typeName ?? "") }
        let depth = nodes[link.parent].depth + 1
        guard depth <= options.maxDepth else { throw .invalid("nested deeper than \(options.maxDepth)", path: "") }
        nodes.append(Node(type: type, depth: depth, name: name, parent: link))
        jobs.append(Job(node: nodes.count - 1, json: json, skipsType: skipsType))
        return nodes.count - 1
    }

    /// An error with its path filled in, when it has none: the names from the root down to `node`, then `field`.
    func locate(_ error: ProtoJSONError, _ node: Int, _ field: String?) -> ProtoJSONError {
        guard case .invalid(let reason, let path) = error, path.isEmpty else { return error }
        var names = field.map { [$0] } ?? []
        var current: Int? = node
        while let index = current {
            names.append(nodes[index].name)
            current = nodes[index].parent?.parent
        }
        return .invalid(reason, path: names.reversed().joined(separator: "."))
    }

    private mutating func fold() throws(ProtoJSONError) -> DynamicMessage {
        var index = nodes.count - 1
        while index > 0 {
            if let link = nodes[index].parent {
                let message = nodes[index].fields.take(typeName: nodes[index].type.name)
                switch link.slot {
                    case .place(let slot): nodes[link.parent].fields.place(message, field: link.field, slot: slot)
                    case .anyValue(let url):
                        let bytes: [UInt8]
                        do throws(DynamicMessageError) {
                            bytes = try schema.encode(message)
                        } catch {
                            throw .dynamic(error)
                        }
                        nodes[link.parent].fields.values[1] = .string(url)
                        if !bytes.isEmpty { nodes[link.parent].fields.values[2] = .bytes(bytes) }
                }
            }
            index -= 1
        }
        return nodes[0].fields.take(typeName: nodes[0].type.name)
    }
}
