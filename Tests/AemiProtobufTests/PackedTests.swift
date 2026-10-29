import AemiProtobuf
import Testing

/// `packed: false` writes one record per element, as proto2 does for a repeated number it does not declare packed.
@Suite struct PackedTests {
    @Test func `expanded and packed fields write protoc's bytes, and read them`() throws {
        let bytes = try TestResource.bytes("expanded")
        let value = Expanded(numbers: [1, 300], deltas: [-1, 2], flags: [true, false])
        #expect(try ProtobufEncoder().encodeToBytes(value) == bytes)
        #expect(try ProtobufDecoder().decode(Expanded.self, fromBytes: bytes) == value)
    }

    @Test func `an expanded field still reads a packed run`() throws {
        #expect(try ProtobufDecoder().decode(Expanded.self, fromBytes: [0x0A, 0x02, 0x01, 0x02]).numbers == [1, 2])
    }
}
