/// Writes frames.
public enum FrameEncoder {
    /// A gRPC frame: flag, big-endian length, payload.
    /// - Precondition: `payload.count` fits in 32 bits, which a message within ``WireLimits`` always does.
    public static func grpc(_ payload: [UInt8], compressed: Bool = false) -> [UInt8] {
        precondition(payload.count <= Int(UInt32.max), "a gRPC frame holds at most 4 GiB - 1")
        let length = UInt32(payload.count)
        var out: [UInt8] = []
        out.reserveCapacity(5 + payload.count)
        out.append(compressed ? 1 : 0)
        for shift in [24, 16, 8, 0] { out.append(UInt8(truncatingIfNeeded: length >> UInt32(shift))) }
        out.append(contentsOf: payload)
        return out
    }

    /// A varint-delimited message: varint length, payload.
    public static func varintDelimited(_ payload: [UInt8]) -> [UInt8] {
        var writer = WireWriter(reservingCapacity: payload.count + 10)
        writer.appendVarint(UInt64(payload.count))
        writer.appendRaw(payload)
        return writer.bytes
    }

    /// A frame in `format`. A compressed flag is only meaningful for gRPC and is ignored otherwise.
    public static func frame(_ payload: [UInt8], format: FrameFormat, compressed: Bool = false) -> [UInt8] {
        switch format {
            case .grpc: grpc(payload, compressed: compressed)
            case .varintDelimited: varintDelimited(payload)
        }
    }
}
