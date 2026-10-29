import AemiProtobuf
import Foundation
import Testing

/// Deterministic fuzzing: every one-byte change and every prefix of valid messages. A decoder may accept or refuse each, and
/// must never trap; a trap ends the test run, so passing is the check.
struct MutationFuzzTests {
    @Test func `every one-byte change of a valid message decodes or throws on the macro path and the generic path`()
        throws
    {
        let kinds = try TestResource.bytes("kinds")
        let outer = try TestResource.bytes("outer")
        var accepted = 0
        var refused = 0
        for index in kinds.indices {
            for change in [UInt8(0x01), 0x80, 0xFF] {
                var mutated = kinds
                mutated[index] ^= change
                if (try? ProtobufDecoder().decode(Kinds.self, fromBytes: mutated)) != nil {
                    accepted += 1
                } else {
                    refused += 1
                }
            }
        }
        for index in outer.indices {
            for change in [UInt8(0x01), 0x80, 0xFF] {
                var mutated = outer
                mutated[index] ^= change
                if (try? ProtobufDecoder().decode(Outer.self, fromBytes: mutated)) != nil {
                    accepted += 1
                } else {
                    refused += 1
                }
            }
        }
        #expect(accepted > 0 && refused > 0, "the corpus must hold both kinds of result")
    }

    @Test func `every prefix of a valid message decodes or throws`() throws {
        let kinds = try TestResource.bytes("kinds")
        let outer = try TestResource.bytes("outer")
        for length in 0 ... kinds.count {
            _ = try? ProtobufDecoder().decode(Kinds.self, fromBytes: Array(kinds[..<length]))
        }
        for length in 0 ... outer.count {
            _ = try? ProtobufDecoder().decode(Outer.self, fromBytes: Array(outer[..<length]))
        }
    }

    @Test func `a length prefix claiming more than the bytes that remain never allocates what it claims`() {
        // field 14 (a_string) claiming 2 GiB, then field 25 (r_string) claiming 4 GiB, with three bytes behind each
        let claims: [[UInt8]] = [
            [0x72, 0x80, 0x80, 0x80, 0x80, 0x08, 1, 2, 3], [0xCA, 0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F, 1, 2, 3]
        ]
        for bytes in claims {
            #expect(throws: (any Error).self) { try ProtobufDecoder().decode(Kinds.self, fromBytes: bytes) }
            #expect(throws: (any Error).self) { try ProtobufDecoder().decode(Outer.self, fromBytes: bytes) }
        }
    }

    @Test func `deeply nested input is refused at the limit and does not exhaust the stack`() {
        var bytes: [UInt8] = []
        for _ in 0 ..< 5_000 { bytes = [0x0A] + varint(bytes.count) + bytes }
        #expect(throws: (any Error).self) { try ProtobufDecoder().decode(Node.self, fromBytes: bytes) }
    }

    private func varint(_ value: Int) -> [UInt8] {
        var out: [UInt8] = []
        var rest = UInt64(value)
        while rest >= 0x80 {
            out.append(UInt8(truncatingIfNeeded: rest) | 0x80)
            rest >>= 7
        }
        return out + [UInt8(rest)]
    }
}
