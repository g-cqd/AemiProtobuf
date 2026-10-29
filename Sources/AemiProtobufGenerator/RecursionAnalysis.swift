/// Which message fields hold, by value, a message that can lead back to their own: those need `@Indirect`, and a oneof with such
/// a member is an `indirect` enumeration. Repeated and map fields store out of line already.
struct RecursionAnalysis {
    /// For each message, the messages its singular and oneof fields hold by value.
    private let edges: [String: Set<String>]
    private var reach: [String: Set<String>] = [:]

    init(edges: [String: Set<String>]) {
        self.edges = edges
        for start in edges.keys { reach[start] = Self.reachable(from: start, edges) }
    }

    /// Whether holding `target` by value inside `owner` would make `owner` contain itself.
    func needsIndirection(owner: String, target: String) -> Bool {
        target == owner || reach[target]?.contains(owner) == true
    }

    private static func reachable(from start: String, _ edges: [String: Set<String>]) -> Set<String> {
        var seen: Set<String> = []
        var pending = Array(edges[start] ?? [])
        while let next = pending.popLast() {
            guard seen.insert(next).inserted else { continue }
            pending.append(contentsOf: edges[next] ?? [])
        }
        return seen
    }
}
