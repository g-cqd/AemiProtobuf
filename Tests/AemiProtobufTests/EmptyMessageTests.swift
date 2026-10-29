import AemiProtobuf
import AemiProtobufCore
import Testing

/// Roadmap 0021: a non-optional message field at its default is left out, as every other non-optional field is; an optional one
/// keeps explicit presence.
@Suite struct EmptyMessageTests {
    private func encode(_ holder: MergeHolder) throws -> [UInt8] { try ProtobufEncoder().encodeToBytes(holder) }

    @Test func `a default message writes nothing`() throws {
        #expect(try encode(MergeHolder()).isEmpty)
        #expect(try encode(MergeHolder(last: 1)) == [0x20, 0x01])
    }

    @Test func `a nested message whose own nested message is empty writes only what is set`() throws {
        #expect(try encode(MergeHolder(pair: MergePair(a: 1))) == [0x0A, 0x02, 0x08, 0x01])
    }

    @Test func `an optional empty message is present and written`() throws {
        #expect(try encode(MergeHolder(maybe: MergePair())) == [0x12, 0x00])
    }

    @Test func `a repeated empty message is written, one record per element`() throws {
        #expect(try encode(MergeHolder(many: [MergePair(), MergePair()])) == [0x1A, 0x00, 0x1A, 0x00])
    }

    @Test func `the core leaves out an empty body and keeps a non-empty one`() throws {
        var writer = WireWriter()
        try writer.appendNonEmptyMessage(field: 1) { _ throws(WireError) in }
        #expect(writer.bytes.isEmpty)
        try writer.appendNonEmptyMessage(field: 1) { w throws(WireError) in
            w.appendTag(1, .varint)
            w.appendVarint(2)
        }
        #expect(writer.bytes == [0x0A, 0x02, 0x08, 0x02])
    }
}
