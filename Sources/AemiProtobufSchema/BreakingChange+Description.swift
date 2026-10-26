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
        }
        self.init(kind: kind, description: description)
    }
}
