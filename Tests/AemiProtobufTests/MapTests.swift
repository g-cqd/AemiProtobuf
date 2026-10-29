import AemiProtobuf
import Foundation
import Testing

/// Roadmap 0025: maps as repeated entry messages, against `protoc --encode --deterministic_output`.
@Suite struct MapTests {
    @Test func `protoc's bytes decode to the sample`() throws {
        #expect(try ProtobufDecoder().decode(Maps.self, fromBytes: TestResource.bytes("maps")) == Maps.sample)
    }

    @Test func `the sample encodes to protoc's deterministic bytes: keys sorted, key and value always written`() throws
    {
        #expect(try ProtobufEncoder().encodeToBytes(Maps.sample) == TestResource.bytes("maps"))
    }

    @Test func `a missing key or value is its default, and a repeated key keeps the last`() throws {
        // names: {value: "x"} (no key), {key: 4} (no value), {key: 4, value: "y"}
        let bytes: [UInt8] = [
            0x0A, 0x03, 0x12, 0x01, 0x78, 0x0A, 0x02, 0x08, 0x04, 0x0A, 0x05, 0x08, 0x04, 0x12, 0x01, 0x79
        ]
        #expect(try ProtobufDecoder().decode(Maps.self, fromBytes: bytes).names == [0: "x", 4: "y"])
    }

    @Test func `an entry's fields in either order, and unknown fields inside it, are read`() throws {
        // counts: {field 9 = 1, value: 5, key: "k"}
        let bytes: [UInt8] = [0x32, 0x07, 0x48, 0x01, 0x10, 0x05, 0x0A, 0x01, 0x6B]
        #expect(try ProtobufDecoder().decode(Maps.self, fromBytes: bytes).counts == ["k": 5])
    }

    @Test func `an entry with a closed enumeration number that has no case goes to the unknown fields`() throws {
        // shades: {key: 1 (zig-zag 2), value: 9}
        let bytes: [UInt8] = [0x1A, 0x04, 0x08, 0x02, 0x10, 0x09]
        let decoded = try ProtobufDecoder().decode(Maps.self, fromBytes: bytes)
        #expect(decoded.shades.isEmpty)
        #expect(decoded.unknownFields.bytes == bytes)
    }

    @Test func `a map key that is not UTF-8 is refused`() {
        #expect(throws: (any Error).self) {
            try ProtobufDecoder().decode(Maps.self, fromBytes: [0x32, 0x04, 0x0A, 0x02, 0xC3, 0x28])
        }
    }
}
