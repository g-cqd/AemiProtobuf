/// What a ``ProtoMessage(unknownFields:)`` does with the fields its type does not declare (ADR-0012).
public enum ProtoUnknownFields: Sendable {
    /// Kept in `unknownFields` and written back: what the protobuf specification asks of proto3 since 3.5.
    case preserve
    /// Skipped: for a format only its own writer reads, such as a cache, where nothing unknown can arrive.
    case discard
}
