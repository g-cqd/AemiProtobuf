import AemiProtobuf
import Testing

/// Roadmap 0022, ADR-0012: fields a message does not declare survive a decode and an encode.
@Suite struct UnknownFieldsTests {
    /// flag = true, then field 31 varint 5, field 32 fixed32, field 33 bytes "hi", field 34 a group holding field 1 = 1.
    private let input: [UInt8] = [
        0x18, 0x01, 0xF8, 0x01, 0x05, 0x85, 0x02, 0x01, 0x02, 0x03, 0x04, 0x8A, 0x02, 0x02, 0x68, 0x69,
        0x93, 0x02, 0x08, 0x01, 0x94, 0x02
    ]

    @Test func `every wire type of an unknown field is kept in order and written back after the known fields`() throws {
        let decoded = try ProtobufDecoder().decode(UnknownHolder.self, fromBytes: input)
        #expect(decoded.flag)
        #expect(decoded.unknownFields.bytes == Array(input[2...]))
        #expect(try ProtobufEncoder().encodeToBytes(decoded) == input)
    }

    @Test func `unknown fields go after the known ones, whatever order they came in`() throws {
        let bytes: [UInt8] = [0xF8, 0x01, 0x05, 0x18, 0x01]
        let decoded = try ProtobufDecoder().decode(UnknownHolder.self, fromBytes: bytes)
        #expect(try ProtobufEncoder().encodeToBytes(decoded) == [0x18, 0x01, 0xF8, 0x01, 0x05])
    }

    @Test func `a declared field with another wire type is kept as unknown`() throws {
        // text (field 4) as a varint
        let decoded = try ProtobufDecoder().decode(UnknownHolder.self, fromBytes: [0x20, 0x07])
        #expect(decoded.text.isEmpty)
        #expect(decoded.unknownFields.bytes == [0x20, 0x07])
    }

    @Test func `a message that discards them drops them`() throws {
        let decoded = try ProtobufDecoder().decode(DiscardHolder.self, fromBytes: input)
        #expect(decoded == DiscardHolder(flag: true))
        #expect(try ProtobufEncoder().encodeToBytes(decoded) == [0x18, 0x01])
    }

    @Test func `equality sees them, and the memberwise initializer still works`() throws {
        let decoded = try ProtobufDecoder().decode(UnknownHolder.self, fromBytes: input)
        #expect(decoded != UnknownHolder(flag: true))
        var cleared = decoded
        cleared.unknownFields = UnknownFields()
        #expect(cleared == UnknownHolder(flag: true))
    }

    @Test func `an unknown group that does not close is refused`() {
        #expect(throws: (any Error).self) {
            try ProtobufDecoder().decode(UnknownHolder.self, fromBytes: [0x93, 0x02, 0x08, 0x01])
        }
    }
}
