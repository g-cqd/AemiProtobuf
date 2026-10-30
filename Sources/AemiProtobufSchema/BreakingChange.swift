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
        /// The field moved into, out of, or between oneofs (`nil` is no oneof; a proto3 `optional` counts as none).
        case fieldOneofChanged(message: String, field: String, oldOneof: String?, newOneof: String?)
        /// The set of required fields differs: a reader of one version refuses messages of the other.
        case requiredFieldsChanged(message: String, oldRequired: [String], newRequired: [String])
        /// Field numbers a message or an enumeration reserved, `start ... end` inclusive, are no longer all reserved.
        case reservedRangeRemoved(scope: String, start: Int32, end: Int32, isEnum: Bool)
        case reservedNameRemoved(scope: String, name: String, isEnum: Bool)
        /// The wire is unchanged; the JSON form is not.
        case fieldJSONNameChanged(message: String, field: String, oldName: String, newName: String)
    }

    public let kind: Kind
    public let description: String

    public init(kind: Kind, description: String) {
        self.kind = kind
        self.description = description
    }

    /// Whether data written by one version is misread or refused by the other. A rename is not: only JSON and source break.
    /// The `buf breaking` rule this change is (buf 1.75's names).
    public var bufRule: String {
        switch kind {
            case .messageRemoved: "MESSAGE_NO_DELETE"
            case .fieldRemoved, .fieldRenumbered: "FIELD_NO_DELETE_UNLESS_NUMBER_RESERVED"
            case .fieldRenamed: "FIELD_SAME_NAME"
            case .fieldTypeIncompatible, .fieldTypeNameChanged: "FIELD_WIRE_COMPATIBLE_TYPE"
            case .fieldLabelChanged: "FIELD_WIRE_COMPATIBLE_CARDINALITY"
            case .enumRemoved: "ENUM_NO_DELETE"
            case .enumValueRemoved, .enumValueRenumbered: "ENUM_VALUE_NO_DELETE_UNLESS_NUMBER_RESERVED"
            case .fieldOneofChanged: "FIELD_SAME_ONEOF"
            case .requiredFieldsChanged: "MESSAGE_SAME_REQUIRED_FIELDS"
            case .reservedRangeRemoved(_, _, _, let isEnum), .reservedNameRemoved(_, _, let isEnum):
                isEnum ? "RESERVED_ENUM_NO_DELETE" : "RESERVED_MESSAGE_NO_DELETE"
            case .fieldJSONNameChanged: "FIELD_SAME_JSON_NAME"
        }
    }

    /// Whether data written by one version is misread or refused by the other: the change is one of buf's WIRE rules. A rename,
    /// a JSON name, and a removed message or enumeration (nothing on the wire names a type) are not.
    public var breaksTheWire: Bool { Self.wireRules.contains(bufRule) }

    static let wireRules: Set<String> = [
        "FIELD_NO_DELETE_UNLESS_NUMBER_RESERVED", "FIELD_WIRE_COMPATIBLE_TYPE", "FIELD_WIRE_COMPATIBLE_CARDINALITY",
        "ENUM_VALUE_NO_DELETE_UNLESS_NUMBER_RESERVED", "FIELD_SAME_ONEOF", "MESSAGE_SAME_REQUIRED_FIELDS",
        "RESERVED_MESSAGE_NO_DELETE", "RESERVED_ENUM_NO_DELETE"
    ]
}
