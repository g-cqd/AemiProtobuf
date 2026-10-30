/// A message read in place (roadmap 0006).
public struct ProtoMessageView: Sendable {
    public init(_ bytes: [UInt8], limits: WireLimits = .default) throws(WireError) { throw .truncated(at: 0) }
}
