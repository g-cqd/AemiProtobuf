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
    /// - Complexity: O(the field's bytes).
    public mutating func readUnknownField(_ tag: FieldTag, into unknown: inout UnknownFields) throws(WireError) {
        let start = tagOffset
        try skipField(tag)
        unsafe unknown.bytes.append(contentsOf: UnsafeRawBufferPointer(rebasing: buffer[start ..< offset]))
    }
}

extension WireWriter {
    /// Writes fields kept by ``WireReader/readUnknownField(_:into:)`` as they were read.
    public mutating func appendUnknownFields(_ unknown: UnknownFields) {
        bytes.append(contentsOf: unknown.bytes)
    }
}

extension UnknownFields {
    /// Keeps a varint field, as a closed enumeration's number with no case is kept.
    public mutating func appendVarint(field: FieldNumber, _ value: UInt64) {
        var writer = WireWriter()
        writer.appendTag(field, .varint)
        writer.appendVarint(value)
        bytes.append(contentsOf: writer.bytes)
    }
}

extension UnknownFields {
    /// Keeps fields already encoded, tag included: a map entry whose closed enumeration value has no case is kept whole.
    public mutating func appendEncoded(_ fields: [UInt8]) {
        bytes.append(contentsOf: fields)
    }
}
