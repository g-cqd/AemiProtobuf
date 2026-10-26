/// A recursive message, to drive the depth limit.
struct Node: Codable, Equatable {
    var children: [Node] = []

    enum CodingKeys: Int, CodingKey { case children = 1 }

    static func chain(depth: Int) -> Node {
        var node = Node()
        for _ in 0 ..< depth { node = Node(children: [node]) }
        return node
    }
}
