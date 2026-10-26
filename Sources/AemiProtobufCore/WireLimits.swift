/// The bounds that keep attacker input from using unbounded stack, memory or time. Both the reader and the writer take one.
public struct WireLimits: Sendable, Equatable {
    /// Nested messages and groups. 100 is the protobuf reference implementations' recursion limit.
    public var maxDepth: Int
    /// Bytes in one message, and in the buffer a reader is given. 2^31-1 is the protobuf size limit.
    public var maxMessageBytes: Int

    public static let `default` = WireLimits()

    public init(maxDepth: Int = 100, maxMessageBytes: Int = Int(Int32.max)) {
        self.maxDepth = maxDepth
        self.maxMessageBytes = maxMessageBytes
    }
}
