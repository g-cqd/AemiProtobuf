/// The occurrences of one field, read in place from the message index's entries: no array of their own (roadmap 0018). A
/// window of the index (`lower ..< upper`) and a field number; one element of a repeated field is a window of one.
struct _FieldOccurrences {
    let storage: [_ProtobufFieldEntry]
    let number: UInt32
    let lower: Int
    let upper: Int

    /// Every occurrence of `number` in the index.
    init(_ index: _ProtobufMessageIndex, number: UInt32) {
        storage = index.entries
        self.number = number
        lower = 0
        upper = index.entries.count
    }

    /// The single entry at `position`.
    init(_ storage: [_ProtobufFieldEntry], at position: Int) {
        self.storage = storage
        number = storage[position].number
        lower = position
        upper = position + 1
    }

    /// The position of the first occurrence at or after `position`, or `upper`.
    func next(from position: Int) -> Int {
        var current = position
        while current < upper, storage[current].number != number { current += 1 }
        return current
    }

    var last: _ProtobufFieldEntry? {
        var position = upper
        while position > lower {
            position -= 1
            if storage[position].number == number { return storage[position] }
        }
        return nil
    }

    /// Calls `body` with every occurrence, in wire order.
    func forEach(_ body: (_ProtobufFieldEntry) throws -> Void) rethrows {
        for position in lower ..< upper where storage[position].number == number { try body(storage[position]) }
    }
}
