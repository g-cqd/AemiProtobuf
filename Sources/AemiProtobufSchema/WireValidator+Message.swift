import AemiProtobufCore

extension WireValidator {
    /// Checks `bytes[range]` as one message of `descriptor`, `depth` messages deep, with at most `budget` findings.
    func checkMessage(
        _ bytes: [UInt8], _ range: Range<Int>, _ descriptor: MessageDescriptor, depth: Int, budget: Int,
        collectNested: Bool
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
                    guard let field = lookup.field(numbered: number) else {
                        if !allowUnknownFields { check.errors.append(.unknownField(tag.fieldNumber, at: r.offset)) }
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
                    if field.type == .message {
                        let payload = try r.readPayloadRange()
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
}
