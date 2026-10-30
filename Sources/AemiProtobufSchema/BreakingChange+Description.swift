extension BreakingChange {
    init(kind: Kind) {
        let description: String
        switch kind {
            case .messageRemoved(let message):
                description = "Message '\(message)' was removed"
            case .fieldRemoved(let message, let field, let number):
                description = "Field '\(field)' (\(number)) in '\(message)' was removed"
            case .fieldRenumbered(let message, let field, let old, let new):
                description = "Field '\(field)' in '\(message)' renumbered from \(old) to \(new)"
            case .fieldTypeIncompatible(let message, let field, let old, let new):
                description = "Field '\(field)' in '\(message)' changed type from \(old) to \(new)"
            case .fieldLabelChanged(let message, let field, let old, let new):
                description = "Field '\(field)' in '\(message)' changed label from \(old) to \(new)"
            case .fieldRenamed(let message, let number, let old, let new):
                description = "Field \(number) in '\(message)' renamed from '\(old)' to '\(new)'"
            case .fieldTypeNameChanged(let message, let field, let old, let new):
                description = "Field '\(field)' in '\(message)' changed type name from \(old) to \(new)"
            case .enumRemoved(let name):
                description = "Enum '\(name)' was removed"
            case .enumValueRenumbered(let name, let value, let old, let new):
                description = "Enum value '\(value)' in '\(name)' renumbered from \(old) to \(new)"
            case .enumValueRemoved(let name, let value, let number):
                description = "Enum value '\(value)' (\(number)) in '\(name)' was removed"
            case .fieldOneofChanged(let message, let field, let old, let new):
                description = "Field '\(field)' in '\(message)' moved from oneof \(old ?? "none") to \(new ?? "none")"
            case .requiredFieldsChanged(let message, let old, let new):
                description = "Required fields of '\(message)' changed from \(old) to \(new)"
            case .reservedRangeRemoved(let scope, let start, let end, _):
                description = "Reserved numbers \(start)...\(end) of '\(scope)' are no longer all reserved"
            case .reservedNameRemoved(let scope, let name, _):
                description = "Reserved name '\(name)' of '\(scope)' is no longer reserved"
            case .fieldJSONNameChanged(let message, let field, let old, let new):
                description = "Field '\(field)' in '\(message)' changed JSON name from '\(old)' to '\(new)'"
        }
        self.init(kind: kind, description: description)
    }
}
