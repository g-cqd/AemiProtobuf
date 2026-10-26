public import AemiProtobufCore

/// Why a value could not be encoded.
public enum ProtobufEncodingError: Error, Sendable, Equatable {
    /// A coding key without an integer value, or one outside `1...536_870_911`.
    case unsupportedCodingKeys(String)
    /// A Swift construct protobuf has no encoding for here: a top-level scalar, a dictionary, a nested container.
    case unsupported(String)
    /// The wire writer refused: nesting or size limit.
    case underlying(WireError)
}
