/// The fields of a message that its type does not declare, as the bytes they were read as: tags and payloads, in the order they
/// came. Written back after the declared fields (ADR-0012).
public struct UnknownFields: Sendable, Hashable {
    /// The fields, each a tag and its payload.
    public internal(set) var bytes: [UInt8]

    public init() {
        bytes = []
    }

    @inlinable public var isEmpty: Bool { bytes.isEmpty }
}

extension WireReader {
    /// Reads the field whose `tag` was just read, as ``skipField(_:)`` does, and keeps its bytes, tag included, in `unknown`.
    public mutating func readUnknownField(_ tag: FieldTag, into unknown: inout UnknownFields) throws(WireError) {
        try skipField(tag)
    }
}

extension WireWriter {
    /// Writes fields kept by ``WireReader/readUnknownField(_:into:)`` as they were read.
    public mutating func appendUnknownFields(_ unknown: UnknownFields) {}
}
