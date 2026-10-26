extension WireReader {
    /// Skips the payload of the field whose `tag` was just read, including a whole group.
    ///
    /// Iterative: open groups live in an array bounded by `limits.maxDepth`, so nesting cannot overflow the stack.
    /// - Complexity: O(bytes skipped).
    /// - Throws: ``WireError/unexpectedEndGroup(at:)`` for an end-group tag, ``WireError/endGroupMismatch(expected:found:at:)``,
    ///   ``WireError/depthExceeded(limit:at:)``, or a truncation error.
    public mutating func skipField(_ tag: FieldTag) throws(WireError) {
        switch tag.wireType {
            case .endGroup:
                throw .unexpectedEndGroup(at: tagOffset)
            case .startGroup:
                try skipGroup(opened: tag.fieldNumber)
            case .varint, .fixed64, .fixed32, .lengthDelimited:
                try skipPayload(of: tag.wireType)
        }
    }

    private mutating func skipPayload(of type: WireType) throws(WireError) {
        switch type {
            case .varint: _ = try readVarint()
            case .fixed64: _ = try readFixed64()
            case .fixed32: _ = try readFixed32()
            case .lengthDelimited: _ = try takePayload()
            case .startGroup, .endGroup: preconditionFailure("groups are skipped by skipGroup")
        }
    }

    private mutating func skipGroup(opened: FieldNumber) throws(WireError) {
        groupScratch.removeAll(keepingCapacity: true)
        groupScratch.append(opened)
        guard depth + groupScratch.count <= limits.maxDepth else {
            throw .depthExceeded(limit: limits.maxDepth, at: tagOffset)
        }
        while let expected = groupScratch.last {
            guard let next = try nextTag() else { throw .truncated(at: offset) }
            switch next.wireType {
                case .startGroup:
                    groupScratch.append(next.fieldNumber)
                    guard depth + groupScratch.count <= limits.maxDepth else {
                        throw .depthExceeded(limit: limits.maxDepth, at: tagOffset)
                    }
                case .endGroup:
                    guard next.fieldNumber == expected else {
                        throw .endGroupMismatch(expected: expected, found: next.fieldNumber, at: tagOffset)
                    }
                    groupScratch.removeLast()
                case .varint, .fixed64, .fixed32, .lengthDelimited:
                    try skipPayload(of: next.wireType)
            }
        }
    }
}
