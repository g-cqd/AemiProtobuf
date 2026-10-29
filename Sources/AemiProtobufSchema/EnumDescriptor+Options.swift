import AemiProtobufCore

/// The `EnumOptions` the generator reads (roadmap 0028).
extension EnumDescriptor {
    /// `option allow_alias = true` (field 2).
    public var allowAlias: Bool { OptionsReader.flag(options, 2) ?? false }
    /// `EnumOptions.features` (field 7).
    public var features: FeatureSet? { OptionsReader.features(options, 7) }
}
