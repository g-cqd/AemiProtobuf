/// One difference between two versions of a schema that can break a reader or a writer of the other version.
public struct BreakingChange: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case messageRemoved(String)
        case fieldRemoved(message: String, field: String, number: Int32)
        /// The name is still in the message, at another number: old data is read as a different field.
        case fieldRenumbered(message: String, field: String, oldNumber: Int32, newNumber: Int32)
        /// The number now carries another name. The wire is unchanged; JSON names and generated code are not.
        case fieldRenamed(message: String, number: Int32, oldName: String, newName: String)
        case fieldTypeIncompatible(message: String, field: String, oldType: FieldType, newType: FieldType)
        /// A message or enum field now names another type.
        case fieldTypeNameChanged(message: String, field: String, oldTypeName: String, newTypeName: String)
        case fieldLabelChanged(message: String, field: String, oldLabel: FieldLabel, newLabel: FieldLabel)
        case enumRemoved(String)
        case enumValueRemoved(enumName: String, value: String, number: Int32)
        case enumValueRenumbered(enumName: String, value: String, oldNumber: Int32, newNumber: Int32)
    }

    public let kind: Kind
    public let description: String

    public init(kind: Kind, description: String) {
        self.kind = kind
        self.description = description
    }

    /// Whether data written by one version is misread or refused by the other. A rename is not: only JSON and source break.
    /// The `buf breaking` rule this change is.
    public var bufRule: String { "" }

    public var breaksTheWire: Bool {
        if case .fieldRenamed = kind { return false }
        return true
    }
}
