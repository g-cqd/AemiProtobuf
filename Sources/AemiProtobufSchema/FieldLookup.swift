/// A message's fields by number. A message with few fields is searched in place: building a dictionary per call cost more than
/// the validation. Construction refuses a descriptor with an illegal or repeated number.
struct FieldLookup {
    /// Descriptors with at most this many fields are searched linearly; larger ones get a dictionary.
    static let linearSearchLimit = 16

    let fields: [FieldDescriptor]
    let table: [Int32: FieldDescriptor]?

    /// - Returns: the lookup, or the finding that says why the descriptor cannot be used.
    static func make(_ fields: [FieldDescriptor]) -> Result<FieldLookup, WireValidationError> {
        let small = fields.count <= linearSearchLimit
        var table: [Int32: FieldDescriptor] = [:]
        for (index, field) in fields.enumerated() {
            guard field.number > 0, field.number <= 536_870_911 else {
                return .failure(.invalidDescriptorNumber(field.number))
            }
            let duplicate =
                small
                ? fields[..<index].contains { $0.number == field.number }
                : table.updateValue(field, forKey: field.number) != nil
            if duplicate { return .failure(.invalidDescriptorNumber(field.number)) }
        }
        return .success(FieldLookup(fields: fields, table: small ? nil : table))
    }

    func field(numbered number: Int32) -> FieldDescriptor? {
        table.map { $0[number] } ?? fields.first { $0.number == number }
    }
}
