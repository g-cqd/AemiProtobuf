extension WireReader {
    /// Reads the group whose start-group `tag` was just read. `body` gets a reader over the group's fields, one level deeper,
    /// without the end-group tag; the caller's reader continues after it.
    ///
    /// The group is first skipped to find where it ends (``skipField(_:)`` matches the end-group tag and bounds the nesting),
    /// then read: groups are rare, and so the extent is known before `body` runs, as a message's is.
    /// - Throws: ``WireError/endGroupMismatch(expected:found:at:)``, a truncation error, ``WireError/depthExceeded(limit:at:)``,
    ///   or whatever `body` throws.
    public mutating func readGroup<R>(
        _ tag: FieldTag, _ body: (inout WireReader) throws(WireError) -> R
    ) throws(WireError) -> R {
        guard depth < limits.maxDepth else { throw .depthExceeded(limit: limits.maxDepth, at: tagOffset) }
        let start = offset
        try skipField(tag)
        var nested = unsafe WireReader(buffer: buffer, offset: start, end: tagOffset, depth: depth + 1, limits: limits)
        return try body(&nested)
    }
}

extension WireReader {
    /// The bytes of the group whose start-group `tag` was just read, without its end-group tag; the reader continues after it.
    /// What ``readGroup(_:_:)`` hands its body, for a caller that reads it later (a validator queues nested messages).
    public mutating func readGroupRange(_ tag: FieldTag) throws(WireError) -> Range<Int> {
        guard depth < limits.maxDepth else { throw .depthExceeded(limit: limits.maxDepth, at: tagOffset) }
        let start = offset
        try skipField(tag)
        return start ..< tagOffset
    }
}
