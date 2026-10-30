/// A field of a ``DynamicMessageType`` with the semantics its descriptor and the edition features in force give it, resolved once.
/// A class, so a lookup hands out a reference rather than copying the descriptor's strings and sets on every field read.
public final class DynamicField: Sendable {
    public let descriptor: FieldDescriptor
    /// The field's type; `.group` for every field written delimited (a proto2 group, or `message_encoding = DELIMITED`).
    public let type: FieldType
    /// `repeated`, a map included.
    public let isRepeated: Bool
    /// A repeated scalar written as one packed run (a reader accepts both forms either way).
    public let isPacked: Bool
    /// Whether a value at its default is written: a message, a oneof member, `optional`, proto2, `field_presence = EXPLICIT`.
    public let hasPresence: Bool
    /// proto2 `required`, or `field_presence = LEGACY_REQUIRED`.
    public let isRequired: Bool
    /// The fully qualified name (no leading dot) of the message, group or enumeration type; for a map, of its entry type.
    public let typeName: String?
    /// The key (1) and value (2) fields of a map's entry type.
    public let mapEntry: MapEntry?
    /// The numbers of a closed enumeration: any other is kept as an unknown field.
    public let closedEnumValues: Set<Int32>?
    /// A `string` that must be UTF-8 (proto3 and editions, unless `utf8_validation = NONE`).
    public let validatesUTF8: Bool
    /// The index of the declared oneof the field is in; a proto3 `optional`'s synthetic oneof is none.
    public let oneofIndex: Int?

    public var name: String { descriptor.name }
    public var number: Int32 { descriptor.number }

    /// The two fields of a map entry.
    public struct MapEntry: Sendable {
        public let key: FieldDescriptor
        public let value: FieldDescriptor
        /// The fully qualified name of the value's message or enumeration type.
        public let valueTypeName: String?
        /// The numbers of the value's enumeration when it is closed: an entry with another is kept as an unknown field.
        public let valueClosedEnumValues: Set<Int32>?
        let keyValidatesUTF8: Bool
        let valueValidatesUTF8: Bool
    }

    /// The values a packed run can hold: the numeric scalars and enumerations.
    static func isPackable(_ type: FieldType) -> Bool {
        switch type {
            case .string, .bytes, .message, .group: false
            default: true
        }
    }

    init(
        _ descriptor: FieldDescriptor, in message: String, features enclosing: ResolvedFeatures, schema: FlatSchema,
        index: SchemaIndex
    ) {
        let features = enclosing.merged(descriptor.features)
        let resolved = descriptor.typeName.isEmpty ? nil : index.resolve(descriptor.typeName, in: message)
        let entry = resolved.flatMap { schema.messages[$0] }.flatMap { $0.isMapEntry ? $0 : nil }
        self.descriptor = descriptor
        self.typeName = resolved
        isRepeated = descriptor.label == .repeated
        let delimited = descriptor.type == .message && entry == nil && features.messageEncoding == 2
        type = delimited ? .group : descriptor.type
        isPacked =
            isRepeated && Self.isPackable(descriptor.type)
            && (descriptor.packed ?? (features.repeatedFieldEncoding == 1))
        isRequired = descriptor.label == .required || features.fieldPresence == 3
        hasPresence =
            !isRepeated
            && (descriptor.type == .message || descriptor.type == .group || descriptor.oneofIndex != nil
                || descriptor.proto3Optional || features.fieldPresence != 2)
        let verify = features.utf8Validation == 2
        mapEntry = entry.flatMap { entry in
            guard let key = entry.fields.first(where: { $0.number == 1 }),
                let value = entry.fields.first(where: { $0.number == 2 }), let entryName = resolved
            else { return nil }
            let valueType = value.typeName.isEmpty ? nil : index.resolve(value.typeName, in: entryName)
            return MapEntry(
                key: key, value: value, valueTypeName: valueType,
                valueClosedEnumValues: value.type == .enum ? valueType.flatMap { schema.closedEnumValues[$0] } : nil,
                keyValidatesUTF8: verify && key.type == .string, valueValidatesUTF8: verify && value.type == .string)
        }
        closedEnumValues = descriptor.type == .enum ? resolved.flatMap { schema.closedEnumValues[$0] } : nil
        validatesUTF8 = descriptor.type == .string && features.utf8Validation == 2
        oneofIndex = descriptor.proto3Optional ? nil : descriptor.oneofIndex.map(Int.init)
    }
}
