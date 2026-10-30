import Testing

@testable import AemiProtobufCore

/// Roadmap 0006: a message read in place. The bytes are indexed once; fields are found by number (the last occurrence of a
/// singular field wins), a missing or mistyped field is `nil`, nested messages are views over the same bytes, and strings and
/// bytes can be read without making a `String` or an array.
@Suite struct ProtoMessageViewTests {
    /// { 1: varint 150, 2: "héllo", 3: { 1: "inner", 2: fixed32 7 }, 4: packed [1, 2, 300], 4: 5, 5: sint32 -3, 1: varint 151,
    ///   6: double 2.5, 7: "a", 7: "b" }
    private static let bytes: [UInt8] = {
        var writer = WireWriter()
        writer.appendTag(1, .varint)
        writer.appendVarint(150)
        writer.appendTag(2, .lengthDelimited)
        writer.appendString("héllo")
        var inner = WireWriter()
        inner.appendTag(1, .lengthDelimited)
        inner.appendString("inner")
        inner.appendTag(2, .fixed32)
        inner.appendFixed32(7)
        writer.appendTag(3, .lengthDelimited)
        writer.appendBytes(inner.bytes)
        writer.appendPackedVarints(field: 4, [1, 2, 300] as [UInt64])
        writer.appendTag(4, .varint)
        writer.appendVarint(5)
        writer.appendTag(5, .varint)
        writer.appendVarint(UInt64(ZigZag.encode(Int32(-3))))
        writer.appendTag(1, .varint)
        writer.appendVarint(151)
        writer.appendTag(6, .fixed64)
        writer.appendDouble(2.5)
        writer.appendRepeatedStrings(field: 7, ["a", "b"])
        return writer.bytes
    }()

    @Test func `scalars are found by number, the last occurrence winning`() throws {
        let view = try ProtoMessageView(Self.bytes)
        #expect(view.uint64(1) == 151)
        #expect(view.int32(1) == 151)
        #expect(view.sint32(5) == -3)
        #expect(view.double(6) == 2.5)
        #expect(view.has(1) && !view.has(9))
        #expect(view.uint64(9) == nil)
        #expect(view.double(1) == nil)  // a varint is not a fixed64
        #expect(view.count == 10)
    }

    @Test func `strings and bytes are read, or borrowed without a copy`() throws {
        let view = try ProtoMessageView(Self.bytes)
        #expect(try view.string(2) == "héllo")
        #expect(view.utf8Equals(2, "héllo") && !view.utf8Equals(2, "hello"))
        #expect(view.withBytes(2) { $0.count } == 6)
        #expect(view.withBytes(9) { $0.count } == nil)
        #expect(try view.strings(7) == ["a", "b"])
    }

    @Test func `nested messages are views over the same bytes`() throws {
        let view = try ProtoMessageView(Self.bytes)
        let inner = try #require(try view.message(3))
        #expect(try inner.string(1) == "inner")
        #expect(inner.fixed32(2) == 7)
        #expect(try view.message(9) == nil)
        #expect(try view.message(3)?.message(1) != nil)  // "inner" parses as a message: field 13, length… or throws
    }

    @Test func `repeated scalars come packed or not, in order`() throws {
        let view = try ProtoMessageView(Self.bytes)
        #expect(try view.varints(4) == [1, 2, 300, 5])
    }

    @Test func `malformed bytes are refused when indexed, and nesting is bounded`() throws {
        #expect(throws: WireError.self) { try ProtoMessageView([0x0A, 0x05, 0x01]) }
        #expect(throws: WireError.self) { try ProtoMessageView([0x0C]) }  // a lone end-group tag
        var bytes: [UInt8] = []
        for _ in 0 ..< 3 {
            var writer = WireWriter()
            writer.appendTag(1, .lengthDelimited)
            writer.appendBytes(bytes)
            bytes = writer.bytes
        }
        let limits = WireLimits(maxDepth: 2)
        let view = try ProtoMessageView(bytes, limits: limits)
        let second = try #require(try view.message(1)?.message(1))
        #expect(throws: WireError.self) { try second.message(1) }
    }
}
