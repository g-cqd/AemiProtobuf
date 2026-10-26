public import AemiProtobufCore

/// Why bytes could not be decoded.
public enum ProtobufDecodingError: Error, Sendable, Equatable {
    /// A coding key without an integer value, or one outside `1...536_870_911`.
    case unsupportedCodingKeys(String)
    /// A Swift construct protobuf has no decoding for here: a dictionary, a nested container, a top-level scalar.
    case unsupported(String)
    /// The bytes are not well-formed protobuf, or exceed a limit.
    case underlying(WireError)
}
