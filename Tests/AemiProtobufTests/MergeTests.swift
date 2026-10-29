import AemiProtobuf
import Foundation
import Testing

/// Roadmap 0020: a message field given more than once merges, as the encoding guide says and `protoc` does.
@Suite struct MergeTests {
    @Test func `two encodings one after the other decode as protoc merges them`() throws {
        let bytes = try TestResource.bytes("merge")
        #expect(try ProtobufDecoder().decode(MergeHolder.self, fromBytes: bytes) == MergeHolder.merged)
    }

    @Test func `a singular message given twice merges, and its scalars keep the last occurrence`() throws {
        // pair {a: 1, b: 7} then pair {b: 2}
        let bytes: [UInt8] = [0x0A, 0x04, 0x08, 0x01, 0x10, 0x07, 0x0A, 0x02, 0x10, 0x02]
        let decoded = try ProtobufDecoder().decode(MergeHolder.self, fromBytes: bytes)
        #expect(decoded.pair == MergePair(a: 1, b: 2))
    }

    @Test func `an optional message given twice merges, and given once is present`() throws {
        let twice: [UInt8] = [0x12, 0x02, 0x08, 0x03, 0x12, 0x02, 0x10, 0x04]
        #expect(try ProtobufDecoder().decode(MergeHolder.self, fromBytes: twice).maybe == MergePair(a: 3, b: 4))
        let empty: [UInt8] = [0x12, 0x00]
        #expect(try ProtobufDecoder().decode(MergeHolder.self, fromBytes: empty).maybe == MergePair())
    }

    @Test func `a merge two levels down merges the inner message too`() throws {
        // pair {inner {a: 5}} then pair {inner {b: 6}}
        let bytes: [UInt8] = [0x0A, 0x04, 0x22, 0x02, 0x08, 0x05, 0x0A, 0x04, 0x22, 0x02, 0x10, 0x06]
        let decoded = try ProtobufDecoder().decode(MergeHolder.self, fromBytes: bytes)
        #expect(decoded.pair.inner == MergeInner(a: 5, b: 6))
    }

    @Test func `a repeated message appends, it does not merge`() throws {
        let bytes: [UInt8] = [0x1A, 0x02, 0x08, 0x01, 0x1A, 0x02, 0x10, 0x02]
        let decoded = try ProtobufDecoder().decode(MergeHolder.self, fromBytes: bytes)
        #expect(decoded.many == [MergePair(a: 1), MergePair(b: 2)])
    }
}
