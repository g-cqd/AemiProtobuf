extension ProtoMessageView {
    /// The field's string, checked as UTF-8.
    /// - Throws: ``WireError/invalidUTF8(at:)``.
    public func string(_ field: FieldNumber) throws(WireError) -> String? {
        guard let entry = last(field, .lengthDelimited) else { return nil }
        return try WireReader.string(from: bytes, in: entry.payload)
    }

    /// Every string of a repeated field, in order.
    public func strings(_ field: FieldNumber) throws(WireError) -> [String] {
        var values: [String] = []
        for entry in entries where entry.number == field.rawValue && entry.wireType == .lengthDelimited {
            values.append(try WireReader.string(from: bytes, in: entry.payload))
        }
        return values
    }

    /// The field's bytes as an array.
    public func bytes(_ field: FieldNumber) -> [UInt8]? {
        last(field, .lengthDelimited).map { Array(bytes[$0.payload]) }
    }

    /// Runs `body` over the field's bytes where they lie: no copy, no `String`. `nil` when the field is absent.
    public func withBytes<R>(_ field: FieldNumber, _ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R? {
        guard let entry = last(field, .lengthDelimited) else { return nil }
        return try bytes.withUnsafeBytes { raw in
            let payload = unsafe UnsafeRawBufferPointer(rebasing: raw[entry.payload])
            return try unsafe body(payload)
        }
    }

    /// Whether the field's bytes are `text`'s UTF-8, compared in place.
    public func utf8Equals(_ field: FieldNumber, _ text: String) -> Bool {
        guard let entry = last(field, .lengthDelimited) else { return false }
        return bytes[entry.payload].elementsEqual(text.utf8)
    }
}
