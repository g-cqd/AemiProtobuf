/// The field numbers (or oneof indices) an object has named so far: a bit mask for the small ones, which are nearly all, and
/// a set only past 63, so checking a message's members for repeats allocates nothing in the common case.
struct SeenFields {
    private var low: UInt64 = 0
    private var high: Set<Int> = []

    /// Records `number`; `false` if it was already recorded.
    mutating func insert(_ number: Int) -> Bool {
        guard number >= 0, number < 64 else { return high.insert(number).inserted }
        let bit: UInt64 = 1 << UInt64(number)
        defer { low |= bit }
        return low & bit == 0
    }
}
