import AemiProtobuf
import Foundation
import Testing

struct FastOnlyTests {
    private let value = FastOnly(id: 150, name: "ann")
    private let wire: [UInt8] = [0x08, 0x96, 0x01, 0x12, 0x03, 0x61, 0x6E, 0x6E]

    @Test func `a type that is only fast-path encodes and decodes through the coders`() throws {
        #expect(try ProtobufEncoder().encodeToBytes(value) == wire)
        #expect(try ProtobufEncoder().encode(value) == Data(wire))
        #expect(try ProtobufDecoder().decode(FastOnly.self, fromBytes: wire) == value)
        #expect(try ProtobufDecoder().decode(FastOnly.self, from: Data(wire)) == value)
    }

    @Test func `a macro type is decoded from Data without going through the Codable path`() throws {
        let leaf = Leaf(name: "abc")
        let data = try ProtobufEncoder().encode(leaf)
        #expect(try ProtobufDecoder().decode(Leaf.self, from: data) == leaf)
    }

    @Test(arguments: [[UInt8]([0x08]), [0x12, 0x05, 0x61], [0x12, 0x01, 0xFF], [0x0B]])
    func `malformed Data throws the same errors as malformed bytes`(bytes: [UInt8]) {
        #expect(throws: ProtobufDecodingError.self) { try ProtobufDecoder().decode(FastOnly.self, from: Data(bytes)) }
        #expect(throws: ProtobufDecodingError.self) { try ProtobufDecoder().decode(FastOnly.self, fromBytes: bytes) }
    }

    @Test func `the limits apply to Data too`() {
        let decoder = ProtobufDecoder(limits: WireLimits(maxDepth: 100, maxMessageBytes: 4))
        #expect(throws: ProtobufDecodingError.underlying(.messageTooLarge(limit: 4))) {
            try decoder.decode(FastOnly.self, from: Data(wire))
        }
    }

    @Test func `a Data slice with a non-zero start decodes correctly`() throws {
        let padded = Data([0xEE, 0xEE] + wire + [0xEE])
        #expect(try ProtobufDecoder().decode(FastOnly.self, from: padded[2 ..< 2 + wire.count]) == value)
    }
}
