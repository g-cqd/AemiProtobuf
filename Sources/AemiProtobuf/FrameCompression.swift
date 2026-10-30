/// What a gRPC frame's compressed flag means: the codec the stream negotiated (gRPC's `grpc-encoding`). AemiProtobuf ships no
/// codec; this is the hook one plugs into (roadmap 0009).
public protocol FrameCompression: Sendable {
    func compress(_ bytes: [UInt8]) throws -> [UInt8]
    func decompress(_ bytes: [UInt8]) throws -> [UInt8]
}
