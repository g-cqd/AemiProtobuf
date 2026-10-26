import AemiProtobufCore
import Foundation

/// Reads the fields of one message by number. An absent field is the proto3 default for `decode`, and `nil` for
/// `decodeIfPresent`. A singular field takes its last occurrence; a nested message given twice is merged.
struct _ProtobufKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K
    let decoder: _ProtobufDecoderImpl
    let index: _ProtobufMessageIndex
    var codingPath: [any CodingKey] { decoder.codingPath }

    var allKeys: [K] {
        var seen = Set<UInt32>()
        return index.entries.compactMap { entry in
            guard seen.insert(entry.number).inserted else { return nil }
            return K(intValue: Int(entry.number))
        }
    }

    private func number(_ key: K) throws -> UInt32 {
        do { return try _ProtobufFieldKey.number(for: key).rawValue } catch let error as ProtobufEncodingError {
            guard case .unsupportedCodingKeys(let reason) = error else { throw error }
            throw ProtobufDecodingError.unsupportedCodingKeys(reason)
        }
    }

    private func last(_ key: K) throws -> _ProtobufFieldEntry? { index.last(for: try number(key)) }

    private func path(_ key: K) -> [any CodingKey] { codingPath + [key] }

    func contains(_ key: K) -> Bool {
        guard let number = try? number(key) else { return false }
        return index.last(for: number) != nil
    }

    func decodeNil(forKey key: K) throws -> Bool { try last(key) == nil }

    // MARK: Required: an absent field is the default

    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool { try _ScalarDecoding.bool(last(key), path(key)) }
    func decode(_ type: String.Type, forKey key: K) throws -> String {
        try _ScalarDecoding.string(last(key), decoder.context.bytes, path(key))
    }
    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        try _ScalarDecoding.double(last(key), path(key))
    }
    func decode(_ type: Float.Type, forKey key: K) throws -> Float { try _ScalarDecoding.float(last(key), path(key)) }
    func decode(_ type: Int.Type, forKey key: K) throws -> Int { try _ScalarDecoding.int(last(key), path(key)) }
    func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 { try _ScalarDecoding.int8(last(key), path(key)) }
    func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 { try _ScalarDecoding.int16(last(key), path(key)) }
    func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 { try _ScalarDecoding.int32(last(key), path(key)) }
    func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 { try _ScalarDecoding.int64(last(key), path(key)) }
    func decode(_ type: UInt.Type, forKey key: K) throws -> UInt { try _ScalarDecoding.uint(last(key), path(key)) }
    func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 { try _ScalarDecoding.uint8(last(key), path(key)) }
    func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
        try _ScalarDecoding.uint16(last(key), path(key))
    }
    func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
        try _ScalarDecoding.uint32(last(key), path(key))
    }
    func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
        try _ScalarDecoding.uint64(last(key), path(key))
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
        if type == Data.self,
            let data = Data(try _ScalarDecoding.bytes(last(key), decoder.context.bytes, path(key))) as? T
        {
            return data
        }
        if type == [UInt8].self,
            let bytes = try _ScalarDecoding.bytes(last(key), decoder.context.bytes, path(key)) as? T
        {
            return bytes
        }
        let entries = index.entries(for: try number(key))
        return try T(from: decoder.field(key, entries: entries))
    }

    // MARK: Optional: absent is nil

    func decodeIfPresent(_ type: Bool.Type, forKey key: K) throws -> Bool? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent(_ type: String.Type, forKey key: K) throws -> String? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent(_ type: Double.Type, forKey key: K) throws -> Double? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent(_ type: Float.Type, forKey key: K) throws -> Float? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent(_ type: Int.Type, forKey key: K) throws -> Int? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent(_ type: Int8.Type, forKey key: K) throws -> Int8? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent(_ type: Int16.Type, forKey key: K) throws -> Int16? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent(_ type: Int32.Type, forKey key: K) throws -> Int32? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent(_ type: Int64.Type, forKey key: K) throws -> Int64? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent(_ type: UInt.Type, forKey key: K) throws -> UInt? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent(_ type: UInt8.Type, forKey key: K) throws -> UInt8? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent(_ type: UInt16.Type, forKey key: K) throws -> UInt16? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent(_ type: UInt32.Type, forKey key: K) throws -> UInt32? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent(_ type: UInt64.Type, forKey key: K) throws -> UInt64? {
        try contains(key) ? decode(type, forKey: key) : nil
    }
    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T? {
        try contains(key) ? decode(type, forKey: key) : nil
    }

    // MARK: Unsupported

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type, forKey key: K
    ) throws -> KeyedDecodingContainer<NestedKey> {
        try decoder.field(key, entries: index.entries(for: number(key))).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> any UnkeyedDecodingContainer {
        try decoder.field(key, entries: index.entries(for: number(key))).unkeyedContainer()
    }

    func superDecoder() throws -> any Decoder {
        throw ProtobufDecodingError.unsupported("superDecoder: class hierarchies are not messages")
    }

    func superDecoder(forKey key: K) throws -> any Decoder {
        throw ProtobufDecodingError.unsupported("superDecoder: class hierarchies are not messages")
    }
}
