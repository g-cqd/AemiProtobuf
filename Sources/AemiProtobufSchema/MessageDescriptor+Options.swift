import AemiProtobufCore

/// The `MessageOptions` the generator reads (roadmap 0028).
extension MessageDescriptor {
    /// `option message_set_wire_format = true` (field 1).
    public var messageSetWireFormat: Bool { OptionsReader.flag(options, 1) ?? false }
    /// A map's synthetic entry message: `map_entry = true` (field 7).
    public var isMapEntry: Bool { OptionsReader.flag(options, 7) ?? false }
    /// `MessageOptions.features` (field 12).
    public var features: FeatureSet? { OptionsReader.features(options, 12) }
}
