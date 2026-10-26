/// Why a stream could not be framed.
public enum FrameError: Error, Sendable, Equatable {
    /// A frame declares a payload longer than the limit. Reported when its header is complete, before any payload is buffered.
    /// `at` is the stream offset of the frame's first byte.
    case lengthExceedsLimit(declared: UInt64, limit: Int, at: Int)
    /// A gRPC flag byte with a bit other than the compressed bit set.
    case invalidFlag(UInt8, at: Int)
    /// A varint length longer than ten bytes, or one that does not fit 64 bits.
    case malformedLength(at: Int)
    /// The stream ended inside a frame; `buffered` bytes of it had arrived.
    case truncated(buffered: Int)
}
