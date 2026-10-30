/// A message type of a ``DynamicSchema``: its fields with their semantics resolved, by number.
public struct DynamicMessageType: Sendable {
    /// The fully qualified name, without a leading dot.
    public let name: String
    public let descriptor: MessageDescriptor
    /// The fields in number order.
    public let fields: [DynamicField]
    private let positions: [Int32: Int]
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
        oneofMembers = Dictionary(grouping: self.fields.filter { $0.oneofIndex != nil }) { $0.oneofIndex ?? 0 }
            .mapValues { $0.map(\.number) }
        requiredFields = self.fields.filter(\.isRequired)
    }

    /// The field with this number, or `nil` if the type declares none.
    public func field(number: Int32) -> DynamicField? { positions[number].map { fields[$0] } }

    /// The field with this name (as declared), or `nil`.
    public func field(named name: String) -> DynamicField? { fields.first { $0.name == name } }

    public var isMapEntry: Bool { descriptor.isMapEntry }
}
