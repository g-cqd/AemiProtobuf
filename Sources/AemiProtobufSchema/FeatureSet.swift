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
    public init(bytes: [UInt8]) throws(WireError) {
        try merge(bytes: bytes)
    }

    /// Sets what `bytes` sets; the rest stays.
    mutating func merge(bytes: [UInt8]) throws(WireError) {
        self = try WireReader.withReader(over: bytes) { r throws(WireError) -> FeatureSet in
            var features = self
            while let tag = try r.nextTag() {
                guard tag.wireType == .varint else {
                    try r.skipField(tag)
                    continue
                }
                let value = try r.readInt32()
                switch tag.fieldNumber.rawValue {
                    case 1: features.fieldPresence = value
                    case 2: features.enumType = value
                    case 3: features.repeatedFieldEncoding = value
                    case 4: features.utf8Validation = value
                    case 5: features.messageEncoding = value
                    case 6: features.jsonFormat = value
                    default: continue
                }
            }
            return features
        }
    }
}
