/// Compares two versions of a schema and lists what breaks a reader or writer of the other version, by `buf breaking`'s WIRE
/// rules: fields are matched by number, as the wire matches them.
///
/// Messages and enums are matched by fully qualified name, nested ones included. The result is in a fixed order: names sorted,
/// then field and value numbers ascending. A field or value whose number the new version reserves is not reported as removed;
/// reserved numbers and names the new version no longer reserves are. `bufRule` names the buf rule of each change, and
/// `breaksTheWire` is whether that rule is one of buf's WIRE rules (`BufBreakingOracleTests` checks fourteen kinds against buf).
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
                } else if !Self.isReserved(field.number, new.reservedRanges, endIncluded: false) {
                    changes.append(
                        BreakingChange(kind: .fieldRemoved(message: message, field: field.name, number: field.number)))
                }
                continue
            }
            let (oldOneof, newOneof) = (Self.oneof(of: field, in: old), Self.oneof(of: current, in: new))
            if oldOneof != newOneof {
                changes.append(
                    BreakingChange(
                        kind: .fieldOneofChanged(
                            message: message, field: current.name, oldOneof: oldOneof, newOneof: newOneof)))
            }
            if !field.jsonName.isEmpty, !current.jsonName.isEmpty, field.jsonName != current.jsonName {
                changes.append(
                    BreakingChange(
                        kind: .fieldJSONNameChanged(
                            message: message, field: current.name, oldName: field.jsonName, newName: current.jsonName)))
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
        let required = { (m: MessageDescriptor) in m.fields.filter { $0.label == .required }.map(\.name).sorted() }
        if required(old) != required(new) {
            changes.append(
                BreakingChange(
                    kind: .requiredFieldsChanged(
                        message: message, oldRequired: required(old), newRequired: required(new))))
        }
        changes += Self.reservedRemoved(
            message, old.reservedRanges, new.reservedRanges, old.reservedNames, new.reservedNames, isEnum: false)
        return changes
    }

    /// The declared oneof a field is in; a proto3 `optional`'s synthetic oneof is none.
    private static func oneof(of field: FieldDescriptor, in message: MessageDescriptor) -> String? {
        guard let index = field.oneofIndex, !field.proto3Optional, message.oneofs.indices.contains(Int(index)) else {
            return nil
        }
        return message.oneofs[Int(index)].name
    }

    /// Whether `number` is in one of `ranges`; a message's range excludes its end, an enumeration's includes it.
    static func isReserved(_ number: Int32, _ ranges: [DescriptorRange], endIncluded: Bool) -> Bool {
        ranges.contains { range in
            guard let start = range.start, let end = range.end else { return false }
            return number >= start && (endIncluded ? number <= end : number < end)
        }
    }

    /// Every old reserved range not covered by the new ones (a shrink counts), and every old reserved name the new version drops.
    private static func reservedRemoved(
        _ scope: String, _ old: [DescriptorRange], _ new: [DescriptorRange], _ oldNames: [String], _ newNames: [String],
        isEnum: Bool
    ) -> [BreakingChange] {
        // As closed intervals, so a message's and an enumeration's ranges compare the same way.
        func closed(_ ranges: [DescriptorRange]) -> [(Int64, Int64)] {
            ranges.compactMap { range in
                guard let start = range.start, let end = range.end else { return nil }
                return (Int64(start), Int64(end) - (isEnum ? 0 : 1))
            }
            .sorted { $0.0 < $1.0 }
        }
        let covering = closed(new)
        var changes: [BreakingChange] = []
        for (start, end) in closed(old) {
            var next = start
            for (low, high) in covering where low <= next && high >= next { next = max(next, high + 1) }
            if next <= end {
                changes.append(
                    BreakingChange(
                        kind: .reservedRangeRemoved(scope: scope, start: Int32(start), end: Int32(end), isEnum: isEnum))
                )
            }
        }
        for name in oldNames where !newNames.contains(name) {
            changes.append(BreakingChange(kind: .reservedNameRemoved(scope: scope, name: name, isEnum: isEnum)))
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
            } else if !Self.isReserved(value.number, new.reservedRanges, endIncluded: true) {
                changes.append(
                    BreakingChange(kind: .enumValueRemoved(enumName: name, value: value.name, number: value.number)))
            }
        }
        changes += Self.reservedRemoved(
            name, old.reservedRanges, new.reservedRanges, old.reservedNames, new.reservedNames, isEnum: true)
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
