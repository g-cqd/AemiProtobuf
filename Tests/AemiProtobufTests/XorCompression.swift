import AemiProtobuf

/// A stand-in compression for the tests: each byte flipped, so a frame read without it is visibly wrong.
struct XorCompression: FrameCompression {
    func compress(_ bytes: [UInt8]) throws -> [UInt8] { bytes.map { $0 ^ 0xFF } }
    func decompress(_ bytes: [UInt8]) throws -> [UInt8] { bytes.map { $0 ^ 0xFF } }
}
