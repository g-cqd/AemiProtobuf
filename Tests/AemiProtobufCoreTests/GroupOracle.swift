/// An independent definition of "skipField consumes a whole group", shared with `Models/tla/GroupSkip.tla`. It uses no stack:
/// it counts opens minus closes to find where the group ends, then cancels adjacent start/end pairs of the same number.
enum GroupOracle {
    enum Token: Equatable {
        case scalar
        case start(UInt32)
        case end(UInt32)

        /// The wire bytes: a scalar is field 9 as a varint 0; a group delimiter is one tag byte (field numbers stay below 16).
        var bytes: [UInt8] {
            switch self {
                case .scalar: [0x48, 0x00]
                case .start(let n): [UInt8(n << 3 | 3)]
                case .end(let n): [UInt8(n << 3 | 4)]
            }
        }
    }

    /// Every token sequence of length 0 through `maxLength` over a scalar and start/end of each number, shortest first.
    static func allSequences(numbers: [UInt32], maxLength: Int) -> [[Token]] {
        let alphabet: [Token] = [.scalar] + numbers.flatMap { [Token.start($0), Token.end($0)] }
        var all: [[Token]] = [[]]
        var frontier: [[Token]] = [[]]
        for _ in 0 ..< maxLength {
            frontier = frontier.flatMap { prefix in alphabet.map { prefix + [$0] } }
            all += frontier
        }
        return all
    }

    /// What reading `[start(opened)] + tokens` as a group should do at nesting limit `maxDepth`.
    /// - Returns: the number of bytes the group takes when it is accepted, `nil` when it must be refused.
    static func acceptedBytes(opened: UInt32, tokens: [Token], maxDepth: Int) -> Int? {
        let whole = [Token.start(opened)] + tokens
        var height = 0
        var peak = 0
        var closeAt: Int?
        for (index, token) in whole.enumerated() {
            switch token {
                case .start: height += 1
                case .end: height -= 1
                case .scalar: break
            }
            peak = max(peak, height)
            if height <= 0 {
                closeAt = index + 1
                break
            }
        }
        guard let closeAt, peak <= maxDepth else { return nil }
        var remaining = whole.prefix(closeAt).filter { $0 != .scalar }
        while let pair = remaining.indices.dropLast()
            .first(where: { index in
                if case .start(let a) = remaining[index], case .end(let b) = remaining[index + 1] { return a == b }
                return false
            })
        {
            remaining.removeSubrange(pair ... (pair + 1))
        }
        guard remaining.isEmpty else { return nil }
        return whole.prefix(closeAt).reduce(0) { $0 + $1.bytes.count }
    }
}
