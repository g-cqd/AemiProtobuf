public import AemiProtobufCore

/// The edition features an options message sets (`google.protobuf.FeatureSet`), as their enumeration numbers; `nil` where it
/// sets none, so the value is inherited (roadmap 0028).
public struct FeatureSet: Sendable, Equatable {
    /// `EXPLICIT` 1, `IMPLICIT` 2, `LEGACY_REQUIRED` 3.
    public var fieldPresence: Int32?
    /// `OPEN` 1, `CLOSED` 2.
    public var enumType: Int32?
    /// `PACKED` 1, `EXPANDED` 2.
    public var repeatedFieldEncoding: Int32?
    /// `VERIFY` 2, `NONE` 3.
    public var utf8Validation: Int32?
    /// `LENGTH_PREFIXED` 1, `DELIMITED` 2.
    public var messageEncoding: Int32?
    /// `ALLOW` 1, `LEGACY_BEST_EFFORT` 2.
    public var jsonFormat: Int32?

    public init() {}

    /// The features in `bytes`, an encoded `FeatureSet`.
    public init(bytes: [UInt8]) throws(WireError) {}
}
