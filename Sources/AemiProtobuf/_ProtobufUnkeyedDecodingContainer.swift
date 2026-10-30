import AemiProtobufCore
import Foundation

/// Reads the elements of one repeated field. A numeric element is either its own varint or fixed-width record, or one value
/// of a packed record; a packed record is expanded the first time a numeric element asks for it, so a field written either
/// way, or both, reads in wire order. An empty length-delimited record is skipped when a number is wanted.
struct _ProtobufUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let decoder: _ProtobufDecoderImpl
    let occurrences: _FieldOccurrences
    private(set) var currentIndex = 0
    /// The position in the index of the next occurrence, or `occurrences.upper`.
    private var cursor: Int
    /// Values of the packed record being read, as entries with the wire type the caller asked for.
    private var buffered: [_ProtobufFieldEntry] = []
    private var bufferedIndex = 0

    init(decoder: _ProtobufDecoderImpl, occurrences: _FieldOccurrences) {
        self.decoder = decoder
        self.occurrences = occurrences
        cursor = occurrences.next(from: occurrences.lower)
    }

    var codingPath: [any CodingKey] { decoder.codingPath }
    var count: Int? { nil }
    var isAtEnd: Bool { bufferedIndex >= buffered.count && cursor >= occurrences.upper }

    private mutating func nextRecord() throws -> _ProtobufFieldEntry {
        try occurrences.storage[nextPosition()]
    }

    /// The index position of the next record, which the caller consumes.
    private mutating func nextPosition() throws -> Int {
        guard cursor < occurrences.upper else {
            throw DecodingError.valueNotFound(
                Any.self, .init(codingPath: codingPath, debugDescription: "no more elements in the repeated field"))
        }
        defer {
            cursor = occurrences.next(from: cursor + 1)
            currentIndex += 1
        }
        return cursor
    }

    /// The next numeric element, expanding a packed record into `wire`-typed values.
    private mutating func nextNumber(_ wire: WireType) throws -> _ProtobufFieldEntry {
        while true {
            if bufferedIndex < buffered.count {
                defer {
                    bufferedIndex += 1
                    currentIndex += 1
                }
                return buffered[bufferedIndex]
            }
            let record = try nextRecord()
            currentIndex -= 1  // `nextRecord` counted the record; its values are counted as they are returned
            guard record.wireType == .lengthDelimited else { return record }
            buffered = try expand(record, wire)
            bufferedIndex = 0
        }
    }

    private func expand(_ record: _ProtobufFieldEntry, _ wire: WireType) throws -> [_ProtobufFieldEntry] {
        var values: [_ProtobufFieldEntry] = []
        do throws(WireError) {
            try WireReader.withReader(
                over: decoder.context.bytes, in: record.range, depth: decoder.depth, limits: decoder.context.limits
            ) { r throws(WireError) in
                while !r.isAtEnd {
                    switch wire {
                        case .fixed32:
                            values.append(
                                .init(
                                    number: record.number, wireType: .fixed32, payload: UInt64(try r.readFixed32()),
                                    length: 0))
                        case .fixed64:
                            values.append(
                                .init(
                                    number: record.number, wireType: .fixed64, payload: try r.readFixed64(), length: 0))
                        default:
                            values.append(
                                .init(number: record.number, wireType: .varint, payload: try r.readVarint(), length: 0))
                    }
                }
            }
        } catch {
            throw ProtobufDecodingError.underlying(error)
        }
        return values
    }

    mutating func decodeNil() throws -> Bool { false }
    mutating func decode(_ type: Bool.Type) throws -> Bool { try _ScalarDecoding.bool(nextNumber(.varint), codingPath) }
    mutating func decode(_ type: String.Type) throws -> String {
        try _ScalarDecoding.string(nextRecord(), decoder.context.bytes, codingPath)
    }
    mutating func decode(_ type: Double.Type) throws -> Double {
        try _ScalarDecoding.double(nextNumber(.fixed64), codingPath)
    }
    mutating func decode(_ type: Float.Type) throws -> Float {
        try _ScalarDecoding.float(nextNumber(.fixed32), codingPath)
    }
    mutating func decode(_ type: Int.Type) throws -> Int { try _ScalarDecoding.int(nextNumber(.varint), codingPath) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { try _ScalarDecoding.int8(nextNumber(.varint), codingPath) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        try _ScalarDecoding.int16(nextNumber(.varint), codingPath)
    }
    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        try _ScalarDecoding.int32(nextNumber(.varint), codingPath)
    }
    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        try _ScalarDecoding.int64(nextNumber(.varint), codingPath)
    }
    mutating func decode(_ type: UInt.Type) throws -> UInt { try _ScalarDecoding.uint(nextNumber(.varint), codingPath) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        try _ScalarDecoding.uint8(nextNumber(.varint), codingPath)
    }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        try _ScalarDecoding.uint16(nextNumber(.varint), codingPath)
    }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        try _ScalarDecoding.uint32(nextNumber(.varint), codingPath)
    }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        try _ScalarDecoding.uint64(nextNumber(.varint), codingPath)
    }

    /// Array calls the generic `decode` for each element; numbers must still read from packed records.
    private mutating func decodeScalar<T: Decodable>(_ type: T.Type) throws -> T? {
        let path = codingPath
        // Identity comparison of the metatype: a runtime `is` chain costs more than reading the element.
        return switch ObjectIdentifier(type) {
            case ObjectIdentifier(Bool.self): try _ScalarDecoding.bool(nextNumber(.varint), path) as? T
            case ObjectIdentifier(Double.self): try _ScalarDecoding.double(nextNumber(.fixed64), path) as? T
            case ObjectIdentifier(Float.self): try _ScalarDecoding.float(nextNumber(.fixed32), path) as? T
            case ObjectIdentifier(Int.self): try _ScalarDecoding.int(nextNumber(.varint), path) as? T
            case ObjectIdentifier(Int8.self): try _ScalarDecoding.int8(nextNumber(.varint), path) as? T
            case ObjectIdentifier(Int16.self): try _ScalarDecoding.int16(nextNumber(.varint), path) as? T
            case ObjectIdentifier(Int32.self): try _ScalarDecoding.int32(nextNumber(.varint), path) as? T
            case ObjectIdentifier(Int64.self): try _ScalarDecoding.int64(nextNumber(.varint), path) as? T
            case ObjectIdentifier(UInt.self): try _ScalarDecoding.uint(nextNumber(.varint), path) as? T
            case ObjectIdentifier(UInt8.self): try _ScalarDecoding.uint8(nextNumber(.varint), path) as? T
            case ObjectIdentifier(UInt16.self): try _ScalarDecoding.uint16(nextNumber(.varint), path) as? T
            case ObjectIdentifier(UInt32.self): try _ScalarDecoding.uint32(nextNumber(.varint), path) as? T
            case ObjectIdentifier(UInt64.self): try _ScalarDecoding.uint64(nextNumber(.varint), path) as? T
            case ObjectIdentifier(String.self):
                try _ScalarDecoding.string(nextRecord(), decoder.context.bytes, path) as? T
            default: nil
        }
    }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if let scalar = try decodeScalar(type) { return scalar }
        let position = try nextPosition()
        let record = occurrences.storage[position]
        if type == Data.self,
            let data = Data(try _ScalarDecoding.bytes(record, decoder.context.bytes, codingPath)) as? T
        {
            return data
        }
        if type == [UInt8].self, let bytes = try _ScalarDecoding.bytes(record, decoder.context.bytes, codingPath) as? T
        {
            return bytes
        }
        return try T(
            from: _ProtobufDecoderImpl(
                context: decoder.context, source: .field(_FieldOccurrences(occurrences.storage, at: position)),
                depth: decoder.depth, codingPath: codingPath))
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<
        NestedKey
    > {
        let position = try nextPosition()
        return try _ProtobufDecoderImpl(
            context: decoder.context, source: .field(_FieldOccurrences(occurrences.storage, at: position)),
            depth: decoder.depth, codingPath: codingPath
        )
        .container(keyedBy: type)
    }

    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw ProtobufDecodingError.unsupported("an array of arrays has no protobuf encoding")
    }

    mutating func superDecoder() throws -> any Decoder {
        throw ProtobufDecodingError.unsupported("superDecoder in an array")
    }
}
