// What changed in a field both sides hold under one number. Apart from SchemaComparator.swift to keep
// that file within the 250 lines SourceStructureTests allows.
extension SchemaComparator {
    /// What changed in a field both sides hold under the same number: its oneof, JSON name, name, type, type name and label.
    func compareKept(
        _ message: String,
        _ field: FieldDescriptor,
        _ current: FieldDescriptor,
        _ old: MessageDescriptor,
        _ new: MessageDescriptor
    ) -> [BreakingChange] {
        var changes: [BreakingChange] = []
        let (oldOneof, newOneof) = (Self.oneof(of: field, in: old), Self.oneof(of: current, in: new))
        if oldOneof != newOneof {
            changes.append(
                BreakingChange(
                    kind: .fieldOneofChanged(
                        message: message,
                        field: current.name,
                        oldOneof: oldOneof,
                        newOneof: newOneof
                    )
                )
            )
        }
        if !field.jsonName.isEmpty, !current.jsonName.isEmpty, field.jsonName != current.jsonName {
            changes.append(
                BreakingChange(
                    kind: .fieldJSONNameChanged(
                        message: message,
                        field: current.name,
                        oldName: field.jsonName,
                        newName: current.jsonName
                    )
                )
            )
        }
        if field.name != current.name {
            changes.append(
                BreakingChange(
                    kind: .fieldRenamed(
                        message: message,
                        number: field.number,
                        oldName: field.name,
                        newName: current.name
                    )
                )
            )
        }
        if !Self.isWireCompatible(old: field.type, new: current.type) {
            changes.append(
                BreakingChange(
                    kind: .fieldTypeIncompatible(
                        message: message,
                        field: current.name,
                        oldType: field.type,
                        newType: current.type
                    )
                )
            )
        } else if field.type == current.type, field.typeName != current.typeName,
            field.type == .message || field.type == .enum
        {
            changes.append(
                BreakingChange(
                    kind: .fieldTypeNameChanged(
                        message: message,
                        field: current.name,
                        oldTypeName: field.typeName,
                        newTypeName: current.typeName
                    )
                )
            )
        }
        if field.label != current.label {
            changes.append(
                BreakingChange(
                    kind: .fieldLabelChanged(
                        message: message,
                        field: current.name,
                        oldLabel: field.label,
                        newLabel: current.label
                    )
                )
            )
        }
        return changes
    }
}
