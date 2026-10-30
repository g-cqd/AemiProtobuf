import AemiProtobufCore

extension WireValidator {
    /// Checks `bytes[range]` as one message of `descriptor`, `depth` messages deep, with at most `budget` findings.
    /// `extensions` are the message's extensions the set declares, by number, checked as its fields; `closedValues` gives the
    /// values of a field's closed enumeration, or `nil` when it is open or unknown.
    func checkMessage(
        _ bytes: [UInt8], _ range: Range<Int>, _ descriptor: MessageDescriptor, depth: Int, budget: Int,
        collectNested: Bool, extensions: [Int32: FieldDescriptor] = [:],
        closedValues: (FieldDescriptor) -> Set<Int32>? = { _ in nil }
    ) -> MessageCheck {
        let lookup: FieldLookup
        switch FieldLookup.make(descriptor.fields) {
            case .success(let made): lookup = made
            case .failure(let error): return MessageCheck(errors: [error])
        }
        var check = MessageCheck()
        var seen: Set<Int32> = []
        var occurrences: [Int32: Int] = [:]
        do {
            try WireReader.withReader(over: bytes, in: range, depth: depth, limits: limits) { r throws(WireError) in
                while !r.isAtEnd {
                    guard check.errors.count < budget else {
                        check.stopped = true
                        break
                    }
                    guard let tag = try r.nextTag() else { break }
                    let number = Int32(tag.fieldNumber.rawValue)
                    guard let field = lookup.field(numbered: number) ?? extensions[number] else {
                        // A number in an extension range is an extension the set does not declare, not an unknown field.
                        let inExtensionRange = descriptor.extensionRanges.contains {
                            ($0.start ?? 0) <= number && number < ($0.end ?? 0)
                        }
                        if !allowUnknownFields, !inExtensionRange {
                            check.errors.append(.unknownField(tag.fieldNumber, at: r.offset))
                        }
                        try r.skipField(tag)
                        continue
                    }
                    let expected = Self.expectedWireType(for: field.type)
                    let packed =
                        field.label == .repeated && tag.wireType == .lengthDelimited && Self.isPackable(expected)
                    guard tag.wireType == expected || packed else {
                        check.errors.append(
                            .unexpectedWireType(field: number, expected: expected, actual: tag.wireType, at: r.offset))
                        try r.skipField(tag)
                        continue
                    }
                    seen.insert(number)
                    if !allowUnknownFields, field.type == .enum, let values = closedValues(field) {
                        try Self.checkEnumValues(field, packed: packed, values, &r, into: &check)
                        continue
                    }
                    if field.type == .message || field.type == .group {
                        // A group's body is checked as the message it holds, as a message field's payload is.
                        let payload = field.type == .group ? try r.readGroupRange(tag) : try r.readPayloadRange()
                        if collectNested {
                            let index = occurrences[number, default: 0]
                            occurrences[number] = index + 1
                            check.nested.append(NestedPayload(field: field, range: payload, index: index))
                        }
                    } else if let error = try validatePayload(
                        tag, field: field, packed: packed, reader: &r, bytes: bytes, depth: depth)
                    {
                        check.errors.append(error)
                    }
                }
            }
        } catch {
            check.errors.append(.wireCorrupted(error))
            check.stopped = check.errors.count > budget
            return check
        }
        if check.stopped { return check }
        for field in descriptor.fields where field.label == .required && !seen.contains(field.number) {
            guard check.errors.count < budget else {
                check.stopped = true
                return check
            }
            check.errors.append(.requiredFieldMissing(field: field.number, name: field.name))
        }
        return check
    }

    /// Reads a closed enumeration's numbers, singular or packed, and reports each one the enumeration has no value for.
    private static func checkEnumValues(
        _ field: FieldDescriptor, packed: Bool, _ values: Set<Int32>, _ r: inout WireReader,
        into check: inout MessageCheck
    ) throws(WireError) {
        func read(_ r: inout WireReader) throws(WireError) {
            let offset = r.offset
            let value = Int32(truncatingIfNeeded: try r.readVarint())
            if !values.contains(value) {
                check.errors.append(.unknownEnumValue(field: field.number, value: value, at: offset))
            }
        }
        if packed {
            try r.readPayload { r throws(WireError) in
                while !r.isAtEnd { try read(&r) }
            }
        } else {
            try read(&r)
        }
    }
}
