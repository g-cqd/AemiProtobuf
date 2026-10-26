/// How messages are delimited in a byte stream.
public enum FrameFormat: Sendable, Equatable {
    /// gRPC: one flag byte (bit 0 set when the payload is compressed, the other bits zero), a four-byte big-endian length, the
    /// payload.
    case grpc
    /// `writeDelimitedTo` of the reference implementations: a varint length, the payload. There is no flag.
    case varintDelimited
}
