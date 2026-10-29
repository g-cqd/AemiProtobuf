import AemiProtobuf
import Testing

/// Roadmap 0023: an open enumeration keeps a number it has no case for; a closed one sends it to the unknown fields, as C++ does.
@Suite struct EnumerationTests {
    private func decode(_ bytes: [UInt8]) throws -> EnumHolder {
        try ProtobufDecoder().decode(EnumHolder.self, fromBytes: bytes)
    }
    private func encode(_ value: EnumHolder) throws -> [UInt8] { try ProtobufEncoder().encodeToBytes(value) }

    @Test func `an open enumeration keeps an unknown number, singular and packed, and writes it back`() throws {
        let bytes: [UInt8] = [0x18, 0x07, 0x22, 0x02, 0x01, 0x07]
        let decoded = try decode(bytes)
        #expect(decoded.open == .unrecognized(7))
        #expect(decoded.opens == [.green, .unrecognized(7)])
        #expect(decoded.unknownFields.isEmpty)
        #expect(try encode(decoded) == bytes)
    }

    @Test func `a closed enumeration sends an unknown number to the unknown fields`() throws {
        let decoded = try decode([0x08, 0x07])
        #expect(decoded.color == .red)
        #expect(decoded.unknownFields.bytes == [0x08, 0x07])
        #expect(try encode(decoded) == [0x08, 0x07])
    }

    @Test func `an unknown number inside a packed run leaves the run as one unpacked record each`() throws {
        let decoded = try decode([0x12, 0x03, 0x01, 0x07, 0x02])
        #expect(decoded.colors == [.green, .blue])
        #expect(decoded.unknownFields.bytes == [0x10, 0x07])
    }

    @Test func `a negative unknown number is kept as its ten-byte varint`() throws {
        let decoded = try decode([0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01])
        #expect(decoded.unknownFields.bytes == [0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01])
    }

    @Test func `a message that discards unknown fields drops an unknown closed number`() throws {
        let decoded = try ProtobufDecoder()
            .decode(DiscardEnumHolder.self, fromBytes: [0x08, 0x07, 0x12, 0x02, 0x01, 0x07])
        #expect(decoded == DiscardEnumHolder(colors: [.green]))
    }
}
