import AemiProtobufCore

/// The `FileOptions` the generator reads, and the syntax a file is written in (roadmap 0028).
extension FileDescriptor {
    /// `FileOptions.features` (field 50).
    public var features: FeatureSet? { OptionsReader.features(options, 50) }

    /// `proto2`, `proto3` or `editions`: protoc writes no `syntax` for a proto2 file, so an empty one is proto2.
    public var resolvedSyntax: String { syntax.isEmpty ? "proto2" : syntax }
}
