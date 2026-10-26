/// Compares two versions of a schema and lists what breaks a reader or writer of the other version, by `buf breaking`'s WIRE
/// rules: fields are matched by number, as the wire matches them.
///
/// Messages and enums are matched by fully qualified name, nested ones included. The result is in a fixed order: names sorted,
/// then field and value numbers ascending. Reserved ranges are not in the descriptor model yet, so a removed field is reported
/// whether or not it was reserved.
public struct SchemaComparator: Sendable {
    public init() {}

    /// - Complexity: O((messages + enums) log n + fields).
    public func compare(old: FileDescriptorSet, new: FileDescriptorSet) -> [BreakingChange] {
        let before = FlatSchema(old)
        let after = FlatSchema(new)
        var changes: [BreakingChange] = []
        for name in before.messages.keys.sorted() {
            guard let oldMessage = before.messages[name] else { continue }
            guard let newMessage = after.messages[name] else {
                changes.append(BreakingChange(kind: .messageRemoved(name)))
                continue
            }
            changes += compareFields(name, oldMessage, newMessage)
        }
        for name in before.enums.keys.sorted() {
            guard let oldEnum = before.enums[name] else { continue }
            guard let newEnum = after.enums[name] else {
                changes.append(BreakingChange(kind: .enumRemoved(name)))
                continue
            }
            changes += compareValues(name, oldEnum, newEnum)
        }
        return changes
    }

    private func compareFields(_ message: String, _ old: MessageDescriptor, _ new: MessageDescriptor)
        -> [BreakingChange]
    {
        let byNumber = Dictionary(new.fields.map { ($0.number, $0) }, uniquingKeysWith: { first, _ in first })
        let byName = Dictionary(new.fields.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        var changes: [BreakingChange] = []
        for field in old.fields.sorted(by: { $0.number < $1.number }) {
            guard let current = byNumber[field.number] else {
                if let moved = byName[field.name] {
                    changes.append(
                        BreakingChange(
                            kind: .fieldRenumbered(
                                message: message, field: field.name, oldNumber: field.number, newNumber: moved.number)))
                } else {
                    changes.append(
                        BreakingChange(kind: .fieldRemoved(message: message, field: field.name, number: field.number)))
                }
                continue
            }
            if field.name != current.name {
                changes.append(
                    BreakingChange(
                        kind: .fieldRenamed(
                            message: message, number: field.number, oldName: field.name, newName: current.name)))
            }
            if !Self.isWireCompatible(old: field.type, new: current.type) {
                changes.append(
                    BreakingChange(
                        kind: .fieldTypeIncompatible(
                            message: message, field: current.name, oldType: field.type, newType: current.type)))
            } else if field.type == current.type, field.typeName != current.typeName,
                field.type == .message || field.type == .enum
            {
                changes.append(
                    BreakingChange(
                        kind: .fieldTypeNameChanged(
                            message: message, field: current.name, oldTypeName: field.typeName,
                            newTypeName: current.typeName)))
            }
            if field.label != current.label {
                changes.append(
                    BreakingChange(
                        kind: .fieldLabelChanged(
                            message: message, field: current.name, oldLabel: field.label, newLabel: current.label)))
            }
        }
        return changes
    }

    private func compareValues(_ name: String, _ old: EnumDescriptor, _ new: EnumDescriptor) -> [BreakingChange] {
        let byNumber = Set(new.values.map(\.number))
        let byName = Dictionary(new.values.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        var changes: [BreakingChange] = []
        for value in old.values.sorted(by: { $0.number < $1.number }) where !byNumber.contains(value.number) {
            if let moved = byName[value.name] {
                changes.append(
                    BreakingChange(
                        kind: .enumValueRenumbered(
                            enumName: name, value: value.name, oldNumber: value.number, newNumber: moved.number)))
            } else {
                changes.append(
                    BreakingChange(kind: .enumValueRemoved(enumName: name, value: value.name, number: value.number)))
            }
        }
        return changes
    }

    /// Wire-compatible pairs: the varint integers and bool together, `sint32` with `sint64`, the two 32-bit fixed types, the two
    /// 64-bit fixed types, `string` with `bytes` (when the data is UTF-8), and a message with `bytes`.
    static func isWireCompatible(old: FieldType, new: FieldType) -> Bool {
        if old == new { return true }
        func group(_ type: FieldType) -> Int? {
            switch type {
                case .int32, .int64, .uint32, .uint64, .bool, .enum: 1
                case .sint32, .sint64: 2
                case .fixed32, .sfixed32: 3
                case .fixed64, .sfixed64: 4
                case .string, .bytes: 5
                default: nil
            }
        }
        if let a = group(old), let b = group(new) { return a == b }
        return (old == .message && new == .bytes) || (old == .bytes && new == .message)
    }
}
