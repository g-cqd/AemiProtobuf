extension WireWriter {
    /// Writes a proto2 group: a start-group tag, what `body` appends, an end-group tag. One level of nesting, as a message.
    /// - Throws: ``WireError/depthExceeded(limit:at:)`` past `limits.maxDepth`, or whatever `body` throws; the writer is then
    ///   unchanged.
    public mutating func appendGroup(
        field: FieldNumber, _ body: (inout WireWriter) throws(WireError) -> Void
    ) throws(WireError) {
        guard depth < limits.maxDepth else { throw .depthExceeded(limit: limits.maxDepth, at: bytes.count) }
        let rollback = bytes.count
        appendTag(field, .startGroup)
        depth += 1
        defer { depth -= 1 }
        do {
            try body(&self)
        } catch {
            bytes.removeSubrange(rollback...)
            throw error
        }
        appendTag(field, .endGroup)
    }
}
