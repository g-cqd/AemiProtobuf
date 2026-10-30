public import AemiProtobufCore

/// A message of a type known only from its descriptor (roadmap 0006): the values of its set fields by number, and the fields its
/// descriptor does not declare. ``DynamicSchema`` reads and writes it.
public struct DynamicMessage: Sendable, Hashable {
    /// The fully qualified name of the message type, without a leading dot.
    public var typeName: String
    /// The fields that are set: a field with explicit presence once set, an implicit-presence one even at its default, a
    /// repeated field or map even when empty. Fields with no value here are not written.
    public var fields: [Int32: DynamicValue]
    /// Fields read that the descriptor does not declare, as they came (ADR-0012); written after the declared fields.
    public var unknownFields: UnknownFields

    public init(typeName: String, fields: [Int32: DynamicValue] = [:], unknownFields: UnknownFields = UnknownFields()) {
        self.typeName = typeName
        self.fields = fields
        self.unknownFields = unknownFields
    }
}
