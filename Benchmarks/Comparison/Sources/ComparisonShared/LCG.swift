/// A fixed-seed generator, so every run and every format sees the same data.
public struct LCG: Sendable {
    var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }

    /// A value in `0..<bound`. `bound` must be positive.
    public mutating func int(_ bound: Int) -> Int { Int(next() >> 33) % max(1, bound) }
}
