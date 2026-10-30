public import AemiProtobufCore
public import Foundation

extension ProtobufEncoder {
    /// A message in a frame of `format`, its payload compressed when `compression` is given (gRPC only).
    public func encodeFrameToBytes<T: Encodable & AemiProtoFastEncodable>(
        _ value: T, format: FrameFormat, compression: (any FrameCompression)? = nil
    ) throws -> [UInt8] { [] }

    public func encodeFrame<T: Encodable & AemiProtoFastEncodable>(
        _ value: T, format: FrameFormat, compression: (any FrameCompression)? = nil
    ) throws -> Data { Data() }
}
