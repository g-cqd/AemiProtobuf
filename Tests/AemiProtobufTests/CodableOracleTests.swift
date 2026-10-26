import AemiProtobuf
import Foundation
import Testing

/// `Resources/outer.bin` is what `protoc --encode=Outer` wrote for `Resources/outer.txt`.
struct CodableOracleTests {
    private func oracle() throws -> [UInt8] {
        let url = try #require(Bundle.module.url(forResource: "outer", withExtension: "bin", subdirectory: "Resources"))
        return [UInt8](try Data(contentsOf: url))
    }

    @Test func `the encoder writes the bytes protoc wrote`() throws {
        #expect(try ProtobufEncoder().encodeToBytes(Outer.sample) == oracle())
    }

    @Test func `the decoder reads what protoc wrote`() throws {
        #expect(try ProtobufDecoder().decode(Outer.self, fromBytes: oracle()) == Outer.sample)
    }

    @Test func `an optional scalar set to zero keeps its presence`() throws {
        var value = Outer()
        value.maybeZero = 0
        let bytes = try ProtobufEncoder().encodeToBytes(value)
        #expect(bytes == [0x32, 0x00, 0x50, 0x00])  // the always-present inner message, then field 10 = 0
        #expect(try ProtobufDecoder().decode(Outer.self, fromBytes: bytes).maybeZero == 0)
        #expect(try ProtobufDecoder().decode(Outer.self, fromBytes: []).maybeZero == nil)
    }

    @Test func `defaults are omitted and an empty message decodes to defaults`() throws {
        #expect(try ProtobufEncoder().encodeToBytes(Outer()) == [0x32, 0x00])  // only the always-present inner message
        #expect(try ProtobufDecoder().decode(Outer.self, fromBytes: []) == Outer())
    }
}
