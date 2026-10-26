/// One message taken from a stream.
public struct Frame: Sendable, Equatable {
    /// `true` when a gRPC frame's compressed bit was set. The payload is then compressed and this library does not decompress it.
    /// Always `false` for ``FrameFormat/varintDelimited``.
    public var isCompressed: Bool
    public var payload: [UInt8]

    public init(isCompressed: Bool = false, payload: [UInt8]) {
        self.isCompressed = isCompressed
        self.payload = payload
    }
}
