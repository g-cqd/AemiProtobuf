import AemiProtobufCore
import Foundation

/// Reads one scalar: the last occurrence of the field, or the default when it is absent.
struct _ProtobufSingleValueDecodingContainer: SingleValueDecodingContainer {
    let decoder: _ProtobufDecoderImpl
    let entry: _ProtobufFieldEntry?
    var codingPath: [any CodingKey] { decoder.codingPath }

    func decodeNil() -> Bool { entry == nil }
    func decode(_ type: Bool.Type) throws -> Bool { try _ScalarDecoding.bool(entry, codingPath) }
    func decode(_ type: String.Type) throws -> String {
        try _ScalarDecoding.string(entry, decoder.context.bytes, codingPath)
    }
    func decode(_ type: Double.Type) throws -> Double { try _ScalarDecoding.double(entry, codingPath) }
    func decode(_ type: Float.Type) throws -> Float { try _ScalarDecoding.float(entry, codingPath) }
    func decode(_ type: Int.Type) throws -> Int { try _ScalarDecoding.int(entry, codingPath) }
    func decode(_ type: Int8.Type) throws -> Int8 { try _ScalarDecoding.int8(entry, codingPath) }
    func decode(_ type: Int16.Type) throws -> Int16 { try _ScalarDecoding.int16(entry, codingPath) }
    func decode(_ type: Int32.Type) throws -> Int32 { try _ScalarDecoding.int32(entry, codingPath) }
    func decode(_ type: Int64.Type) throws -> Int64 { try _ScalarDecoding.int64(entry, codingPath) }
    func decode(_ type: UInt.Type) throws -> UInt { try _ScalarDecoding.uint(entry, codingPath) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try _ScalarDecoding.uint8(entry, codingPath) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try _ScalarDecoding.uint16(entry, codingPath) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try _ScalarDecoding.uint32(entry, codingPath) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try _ScalarDecoding.uint64(entry, codingPath) }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { try T(from: decoder) }
}
