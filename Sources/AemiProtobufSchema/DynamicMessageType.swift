/// A message type of a ``DynamicSchema``: its fields with their semantics resolved, by number.
/// A class, for the same reason as ``DynamicField``: the decoder reaches it once per field.
public final class DynamicMessageType: Sendable {
    /// The fully qualified name, without a leading dot.
    public let name: String
    public let descriptor: MessageDescriptor
    /// The fields in number order.
    public let fields: [DynamicField]
    private let positions: [Int32: Int]
    /// Positions by number for numbers up to a small bound (`-1` for none): an array index instead of a hash per field read.
    private let dense: [Int]
    /// The fields of each declared oneof, by the oneof's index.
    let oneofMembers: [Int: [Int32]]
    /// The required fields, checked after a read.
    let requiredFields: [DynamicField]

    init(name: String, descriptor: MessageDescriptor, fields: [DynamicField]) {
        self.name = name
        self.descriptor = descriptor
        self.fields = fields.sorted { $0.number < $1.number }
        positions = Dictionary(
            self.fields.enumerated().map { ($0.element.number, $0.offset) }, uniquingKeysWith: { first, _ in first })
        let bound = min((self.fields.last.map { Int($0.number) } ?? 0) + 1, 2_048)
        var dense = [Int](repeating: -1, count: bound)
        for (offset, field) in self.fields.enumerated() where Int(field.number) < bound && field.number > 0 {
            dense[Int(field.number)] = offset
        }
        self.dense = dense
        oneofMembers = Dictionary(grouping: self.fields.filter { $0.oneofIndex != nil }) { $0.oneofIndex ?? 0 }
            .mapValues { $0.map(\.number) }
        requiredFields = self.fields.filter(\.isRequired)
    }

    /// The field with this number, or `nil` if the type declares none.
    public func field(number: Int32) -> DynamicField? {
        if number >= 0, Int(number) < dense.count {
            let position = dense[Int(number)]
            return position < 0 ? nil : fields[position]
        }
        return positions[number].map { fields[$0] }
    }

    /// The field with this name (as declared), or `nil`.
    public func field(named name: String) -> DynamicField? { fields.first { $0.name == name } }

    public var isMapEntry: Bool { descriptor.isMapEntry }
}
