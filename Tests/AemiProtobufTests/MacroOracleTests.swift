import AemiProtobuf
import AemiProtobufCore
import Foundation
import Testing

/// `Resources/kinds.bin` is what `protoc --encode=Kinds` wrote for `Resources/kinds.txt`.
struct MacroOracleTests {
    private func oracle() throws -> [UInt8] {
        let url = try #require(Bundle.module.url(forResource: "kinds", withExtension: "bin", subdirectory: "Resources"))
        return [UInt8](try Data(contentsOf: url))
    }

    @Test func `the generated fast path writes the bytes protoc wrote`() throws {
        var writer = WireWriter()
        try Kinds.sample.__aepbEncode(into: &writer)
        #expect(writer.bytes == (try oracle()))
    }

    @Test func `the generated fast path reads what protoc wrote`() throws {
        let decoded = try WireReader.withReader(over: try oracle()) { r throws(WireError) in
            try Kinds.__aepbDecode(from: &r)
        }
        #expect(decoded == Kinds.sample)
    }

    @Test func `the encoder and decoder take the generated fast path`() throws {
        #expect(try ProtobufEncoder().encodeToBytes(Kinds.sample) == (try oracle()))
        #expect(try ProtobufDecoder().decode(Kinds.self, fromBytes: try oracle()) == Kinds.sample)
    }

    @Test func `the generated Codable conformance uses the field numbers as integer keys`() throws {
        // Foundation's JSON coder sees the generated CodingKeys by name, so a round trip proves they cover every field.
        let json = try JSONEncoder().encode(Kinds.sample)
        #expect(try JSONDecoder().decode(Kinds.self, from: json) == Kinds.sample)
        #expect(Kinds.CodingKeys.aSint32.intValue == 5)
        #expect(Kinds.CodingKeys.rLeaf.intValue == 27)
    }

    @Test func `an empty message is all defaults and writes nothing`() throws {
        var writer = WireWriter()
        try Kinds().__aepbEncode(into: &writer)
        // Field 17, the non-optional nested message, is at its default too (roadmap 0021).
        #expect(writer.bytes.isEmpty)
    }

    @Test func `a field with another wire type, an unknown field and an unknown enum number are skipped`() throws {
        // a_int32 as fixed32, unknown field 100, color = 9 (no case), then a_int32 = 3
        let bytes: [UInt8] = [0x0D, 1, 0, 0, 0, 0xA0, 0x06, 0x01, 0x80, 0x01, 0x09, 0x08, 0x03]
        let decoded = try ProtobufDecoder().decode(Kinds.self, fromBytes: bytes)
        #expect(decoded.aInt32 == 3)
        #expect(decoded.color == .red)
    }

    @Test func `packed and unpacked repeated numbers mix`() throws {
        // r_sint32: unpacked 2 (zig-zag 4), then packed [-1 (1), 3 (6)]
        let bytes: [UInt8] = [0xA0, 0x01, 0x04, 0xA2, 0x01, 0x02, 0x01, 0x06]
        #expect(try ProtobufDecoder().decode(Kinds.self, fromBytes: bytes).rSint32 == [2, -1, 3])
    }

    @Test func `a packed run costs no nesting level but a nested message does`() throws {
        let flat = ProtobufDecoder(limits: WireLimits(maxDepth: 0))
        // r_sint32 packed [-1, 3] and r_fixed64 packed [1], at the top level, with no nesting allowed
        let packed: [UInt8] = [0xA2, 0x01, 0x02, 0x01, 0x06, 0xAA, 0x01, 0x08, 1, 0, 0, 0, 0, 0, 0, 0]
        let decoded = try flat.decode(Kinds.self, fromBytes: packed)
        #expect(decoded.rSint32 == [-1, 3] && decoded.rFixed64 == [1])
        #expect(throws: (any Error).self) { try flat.decode(Kinds.self, fromBytes: [0x8A, 0x01, 0x00]) }
    }

    @Test func `truncated and malformed input throws and never traps`() {
        for bytes in [[UInt8]([0x08]), [0x72, 0x05, 0x61], [0xA2, 0x01, 0x01, 0x80], [0x8A, 0x01, 0x02, 0x0A]] {
            #expect(throws: (any Error).self) { try ProtobufDecoder().decode(Kinds.self, fromBytes: bytes) }
        }
    }
}
