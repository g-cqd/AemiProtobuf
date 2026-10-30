public import AemiProtobufCore
public import Foundation

extension ProtobufEncoder {
    /// A message in a frame of `format`, its payload compressed when `compression` is given.
    /// - Throws: ``ProtobufEncodingError/unsupported(_:)`` for compression with varint-delimited framing, which has no flag to
    ///   say so; whatever encoding or the compression throws.
    public func encodeFrameToBytes<T: Encodable & AemiProtoFastEncodable>(
        _ value: T, format: FrameFormat, compression: (any FrameCompression)? = nil
    ) throws -> [UInt8] {
        let payload = try encodeToBytes(value)
        guard let compression else { return FrameEncoder.frame(payload, format: format) }
        guard format == .grpc else {
            throw ProtobufEncodingError.unsupported("a varint-delimited frame has no compressed flag")
        }
        return FrameEncoder.grpc(try compression.compress(payload), compressed: true)
    }

    public func encodeFrame<T: Encodable & AemiProtoFastEncodable>(
        _ value: T, format: FrameFormat, compression: (any FrameCompression)? = nil
    ) throws -> Data {
        Data(try encodeFrameToBytes(value, format: format, compression: compression))
    }
}
