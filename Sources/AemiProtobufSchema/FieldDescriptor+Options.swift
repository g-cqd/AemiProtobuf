import AemiProtobufCore

/// The `FieldOptions` the generator reads (roadmap 0028).
extension FieldDescriptor {
    /// `[packed = …]`; nil when the field does not say.
    public var packed: Bool? { OptionsReader.flag(options, 2) }
    /// The field's own edition features (`FieldOptions.features`, field 21).
    public var features: FeatureSet? { OptionsReader.features(options, 21) }
}
