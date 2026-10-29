/// The options the generator reads, decoded from the raw options messages on demand (roadmap 0028).
extension FieldDescriptor {
    /// `[packed = …]`; nil when the field does not say.
    public var packed: Bool? { nil }
    /// The field's own edition features.
    public var features: FeatureSet? { nil }
}

extension MessageDescriptor {
    /// A map's synthetic entry message (`map_entry = true`).
    public var isMapEntry: Bool { false }
    /// `option message_set_wire_format = true`.
    public var messageSetWireFormat: Bool { false }
    public var features: FeatureSet? { nil }
}

extension EnumDescriptor {
    /// `option allow_alias = true`.
    public var allowAlias: Bool { false }
    public var features: FeatureSet? { nil }
}

extension FileDescriptor {
    public var features: FeatureSet? { nil }
}
