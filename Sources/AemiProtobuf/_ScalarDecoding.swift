import AemiProtobufCore

/// Turns a field occurrence into a Swift scalar. An absent field (`nil`) is the proto3 default, zero or empty. A wire type
/// that does not match the requested type is an error, not a skipped field: reading it as another type would hide a schema
/// mismatch.
enum _ScalarDecoding {
    private static func mismatch(
        _ type: any Any.Type, _ expected: String, _ entry: _ProtobufFieldEntry,
        _ path: @autoclosure () -> [any CodingKey]
    ) -> DecodingError {
        .typeMismatch(
            type,
            .init(
                codingPath: path(), debugDescription: "expected a \(expected) value, found wire type \(entry.wireType)")
        )
    }

    private static func outOfRange(_ type: any Any.Type, _ value: UInt64, _ path: @autoclosure () -> [any CodingKey])
        -> DecodingError
    {
        .dataCorrupted(.init(codingPath: path(), debugDescription: "\(value) does not fit \(type)"))
    }

    static func varint(_ e: _ProtobufFieldEntry?, _ type: any Any.Type, _ path: @autoclosure () -> [any CodingKey])
        throws -> UInt64
    {
        guard let e else { return 0 }
        guard case .varint(let v)? = e.scalar else { throw mismatch(type, "varint", e, path()) }
        return v
    }

    static func bool(_ e: _ProtobufFieldEntry?, _ path: @autoclosure () -> [any CodingKey]) throws -> Bool {
        try varint(e, Bool.self, path()) != 0
    }

    static func int64(_ e: _ProtobufFieldEntry?, _ path: @autoclosure () -> [any CodingKey]) throws -> Int64 {
        Int64(bitPattern: try varint(e, Int64.self, path()))
    }

    /// `int32` is the low 32 bits of the varint, as the reference implementations read it.
    static func int32(_ e: _ProtobufFieldEntry?, _ path: @autoclosure () -> [any CodingKey]) throws -> Int32 {
        Int32(truncatingIfNeeded: try varint(e, Int32.self, path()))
    }

    static func uint32(_ e: _ProtobufFieldEntry?, _ path: @autoclosure () -> [any CodingKey]) throws -> UInt32 {
        UInt32(truncatingIfNeeded: try varint(e, UInt32.self, path()))
    }

    static func uint64(_ e: _ProtobufFieldEntry?, _ path: @autoclosure () -> [any CodingKey]) throws -> UInt64 {
        try varint(e, UInt64.self, path())
    }

    static func int(_ e: _ProtobufFieldEntry?, _ path: @autoclosure () -> [any CodingKey]) throws -> Int {
        let v = try varint(e, Int.self, path())
        guard let value = Int(exactly: Int64(bitPattern: v)) else { throw outOfRange(Int.self, v, path()) }
        return value
    }

    static func int8(_ e: _ProtobufFieldEntry?, _ path: @autoclosure () -> [any CodingKey]) throws -> Int8 {
        let v = try varint(e, Int8.self, path())
        guard let value = Int8(exactly: Int64(bitPattern: v)) else { throw outOfRange(Int8.self, v, path()) }
        return value
    }

    static func int16(_ e: _ProtobufFieldEntry?, _ path: @autoclosure () -> [any CodingKey]) throws -> Int16 {
        let v = try varint(e, Int16.self, path())
        guard let value = Int16(exactly: Int64(bitPattern: v)) else { throw outOfRange(Int16.self, v, path()) }
        return value
    }

    static func uint(_ e: _ProtobufFieldEntry?, _ path: @autoclosure () -> [any CodingKey]) throws -> UInt {
        let v = try varint(e, UInt.self, path())
        guard let value = UInt(exactly: v) else { throw outOfRange(UInt.self, v, path()) }
        return value
    }

    static func uint8(_ e: _ProtobufFieldEntry?, _ path: @autoclosure () -> [any CodingKey]) throws -> UInt8 {
        let v = try varint(e, UInt8.self, path())
        guard let value = UInt8(exactly: v) else { throw outOfRange(UInt8.self, v, path()) }
        return value
    }

    static func uint16(_ e: _ProtobufFieldEntry?, _ path: @autoclosure () -> [any CodingKey]) throws -> UInt16 {
        let v = try varint(e, UInt16.self, path())
        guard let value = UInt16(exactly: v) else { throw outOfRange(UInt16.self, v, path()) }
        return value
    }

    static func double(_ e: _ProtobufFieldEntry?, _ path: @autoclosure () -> [any CodingKey]) throws -> Double {
        guard let e else { return 0 }
        guard case .fixed64(let bits)? = e.scalar else { throw mismatch(Double.self, "fixed64", e, path()) }
        return Double(bitPattern: bits)
    }

    static func float(_ e: _ProtobufFieldEntry?, _ path: @autoclosure () -> [any CodingKey]) throws -> Float {
        guard let e else { return 0 }
        guard case .fixed32(let bits)? = e.scalar else { throw mismatch(Float.self, "fixed32", e, path()) }
        return Float(bitPattern: bits)
    }

    static func string(_ e: _ProtobufFieldEntry?, _ bytes: [UInt8], _ path: @autoclosure () -> [any CodingKey]) throws
        -> String
    {
        guard let e else { return "" }
        guard e.wireType == .lengthDelimited else { throw mismatch(String.self, "length-delimited", e, path()) }
        do throws(WireError) { return try WireReader.string(from: bytes, in: e.range) } catch {
            throw ProtobufDecodingError.underlying(error)
        }
    }

    static func bytes(_ e: _ProtobufFieldEntry?, _ bytes: [UInt8], _ path: @autoclosure () -> [any CodingKey]) throws
        -> [UInt8]
    {
        guard let e else { return [] }
        guard e.wireType == .lengthDelimited else { throw mismatch([UInt8].self, "length-delimited", e, path()) }
        return Array(bytes[e.range])
    }
}
