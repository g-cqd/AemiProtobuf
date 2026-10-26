import Testing

@testable import AemiProtobufCore

/// The real reader against the oracle that `Models/tla/GroupSkip.tla` is checked with, over every token sequence of up to six
/// tokens, two field numbers and four depth limits (about 156,000 inputs). The model checks the algorithm; this checks the code.
struct WireGroupSkipExhaustiveTests {
    @Test func `skipField agrees with the oracle on every short group, at every depth limit`() throws {
        let sequences = GroupOracle.allSequences(numbers: [1, 2], maxLength: 6)
        var disagreements: [String] = []
        var accepted = 0
        var refused = 0
        for maxDepth in 1 ... 4 {
            for opened: UInt32 in [1, 2] {
                for tokens in sequences {
                    let bytes = ([GroupOracle.Token.start(opened)] + tokens).flatMap(\.bytes)
                    let expected = GroupOracle.acceptedBytes(opened: opened, tokens: tokens, maxDepth: maxDepth)
                    let actual: Int?
                    do throws(WireError) {
                        actual = try read(bytes, limits: WireLimits(maxDepth: maxDepth)) { r throws(WireError) in
                            try r.skipField(try tag(&r))
                            return r.offset
                        }
                    } catch {
                        actual = nil
                    }
                    if actual == expected {
                        if expected == nil { refused += 1 } else { accepted += 1 }
                    } else {
                        disagreements.append(
                            "depth \(maxDepth) start(\(opened)) \(tokens): oracle \(String(describing: expected)), reader \(String(describing: actual))"
                        )
                    }
                }
            }
        }
        #expect(disagreements.prefix(5).joined(separator: "\n") == "", "\(disagreements.count) disagreements")
        #expect(
            accepted > 1000 && refused > 1000,
            "the corpus must exercise both outcomes: \(accepted) accepted, \(refused) refused")
    }

    @Test func `the oracle itself accepts and refuses the cases a person can check`() {
        #expect(GroupOracle.acceptedBytes(opened: 1, tokens: [.end(1)], maxDepth: 1) == 2)
        #expect(GroupOracle.acceptedBytes(opened: 1, tokens: [.scalar, .end(1), .scalar], maxDepth: 1) == 4)
        #expect(GroupOracle.acceptedBytes(opened: 1, tokens: [.end(2)], maxDepth: 1) == nil)
        #expect(GroupOracle.acceptedBytes(opened: 1, tokens: [.scalar], maxDepth: 1) == nil)
        #expect(GroupOracle.acceptedBytes(opened: 1, tokens: [.start(2), .end(2), .end(1)], maxDepth: 1) == nil)
        #expect(GroupOracle.acceptedBytes(opened: 1, tokens: [.start(2), .end(2), .end(1)], maxDepth: 2) == 4)
    }
}
