import Testing

@testable import AemiProtobufCore

/// Every case is attacker input. The reader must throw a typed error with the right offset, never trap, never read past
/// the buffer, and never spin.
struct WireReaderMalformedTests {
    @Test func `an empty buffer has no field`() throws {
        let tag = try read([]) { r throws(WireError) in try r.nextTag() }
        #expect(tag == nil)
    }

    @Test(
        arguments: [
            ([UInt8]([0x80]), WireError.truncated(at: 0)),
            ([0xFF, 0xFF], .truncated(at: 0)),
            // protoc truncates a tenth byte above 1; we refuse (ADR-0003)
            ([UInt8](repeating: 0xFF, count: 9) + [0x02], .malformedVarint(at: 0)),
            ([UInt8](repeating: 0x80, count: 10) + [0x00], .malformedVarint(at: 0))  // an eleventh byte is never valid
        ] as [([UInt8], WireError)])
    func `a bad varint is refused`(bytes: [UInt8], expected: WireError) {
        #expect(throws: expected) { _ = try read(bytes) { r throws(WireError) in try r.readVarint() } }
    }

    @Test func `a ten-byte varint whose last byte is 01 is the largest valid value`() throws {
        let bytes = [UInt8](repeating: 0xFF, count: 9) + [0x01]
        let value = try read(bytes) { r throws(WireError) in try r.readVarint() }
        #expect(value == UInt64.max)
    }

    /// A tag is a 32-bit value: C++ reads it in at most five bytes, so a longer encoding of a small tag is refused too, not only
    /// a value above 32 bits (the conformance suite's `BadTag_OverlongVarint`).
    @Test func `a tag written in more than five bytes is refused, and five is accepted`() throws {
        let overlong: [UInt8] = [0x88, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x00, 0x01]
        #expect(throws: WireError.invalidTag(8, at: 0)) { _ = try read(overlong) { r throws(WireError) in try r.nextTag() } }
        let five: [UInt8] = [0x88, 0x80, 0x80, 0x80, 0x00, 0x01]
        let tag = try read(five) { r throws(WireError) in try r.nextTag() }
        #expect(tag?.fieldNumber == 1)
    }

    @Test func `field zero is not a field`() {
        #expect(throws: WireError.invalidTag(0, at: 0)) {
            _ = try read([0x00, 0x01]) { r throws(WireError) in try r.nextTag() }
        }
    }

    @Test(arguments: [[UInt8]([0x01, 0, 0]), [0x01], []])
    func `a truncated fixed32 is refused`(bytes: [UInt8]) {
        #expect(throws: WireError.truncated(at: 0)) {
            _ = try read(bytes) { r throws(WireError) in try r.readFixed32() }
        }
    }

    @Test func `a truncated fixed64 is refused`() {
        #expect(throws: WireError.truncated(at: 0)) {
            _ = try read([UInt8](repeating: 1, count: 7)) { r throws(WireError) in try r.readFixed64() }
        }
    }

    @Test func `a length past the end of the buffer is refused and reports both numbers`() {
        let bytes = hex("05 61 62")  // declares 5 bytes, 2 follow
        #expect(throws: WireError.lengthOutOfBounds(declared: 5, remaining: 2, at: 0)) {
            _ = try read(bytes) { r throws(WireError) in try r.readBytes() }
        }
    }

    @Test func `a length that does not fit in Int is refused`() {
        let bytes = hex("ff ff ff ff ff ff ff ff ff 01")  // UInt64.max
        #expect(throws: WireError.lengthOutOfBounds(declared: UInt64.max, remaining: 0, at: 0)) {
            _ = try read(bytes) { r throws(WireError) in try r.readBytes() }
        }
    }

    @Test func `a buffer exactly at the message limit is accepted`() throws {
        let atEnd = try read([1, 2, 3], limits: WireLimits(maxMessageBytes: 3)) { r throws(WireError) in r.isAtEnd }
        #expect(!atEnd)
    }

    @Test func `a buffer larger than the message limit is refused before any read`() {
        #expect(throws: WireError.messageTooLarge(limit: 3)) {
            _ = try read([1, 2, 3, 4], limits: WireLimits(maxMessageBytes: 3)) { r throws(WireError) in r.isAtEnd }
        }
    }

    @Test(arguments: [
        [UInt8]([0xC0, 0x80]),  // overlong NUL
        [0xED, 0xA0, 0x80],  // a surrogate half
        [0xF4, 0x90, 0x80, 0x80],  // above U+10FFFF
        [0xE2, 0x82],  // truncated sequence
        [0xFF]
    ])
    func `a string that is not UTF-8 is refused`(payload: [UInt8]) {
        let bytes = [UInt8(payload.count)] + payload
        #expect(throws: WireError.invalidUTF8(at: 1)) {
            _ = try read(bytes) { r throws(WireError) in try r.readString() }
        }
    }

    @Test func `a string with multibyte scalars decodes`() throws {
        let text = "héllo ✓ 😀"
        let bytes = try written { $0.appendString(text) }
        let back = try read(bytes) { r throws(WireError) in try r.readString() }
        #expect(back == text)
    }

    @Test func `an empty string and empty bytes decode`() throws {
        let bytes = try written {
            $0.appendString("")
            $0.appendBytes([])
        }
        let (string, data) = try read(bytes) { r throws(WireError) in (try r.readString(), try r.readBytes()) }
        #expect(string == "")
        #expect(data == [])
    }

    @Test func `skipping every wire type consumes exactly its payload`() throws {
        // field 1 varint, 2 fixed64, 3 bytes, 4 fixed32, 5 group{ 1 varint }, then a sentinel varint field 9.
        var w = WireWriter()
        w.appendTag(1, .varint)
        w.appendVarint(300)
        w.appendTag(2, .fixed64)
        w.appendFixed64(7)
        w.appendTag(3, .lengthDelimited)
        w.appendString("abc")
        w.appendTag(4, .fixed32)
        w.appendFixed32(7)
        w.appendTag(5, .startGroup)
        w.appendTag(1, .varint)
        w.appendVarint(1)
        w.appendTag(5, .endGroup)
        w.appendTag(9, .varint)
        w.appendVarint(42)
        let (last, value, atEnd) = try read(w.bytes) { r throws(WireError) in
            for _ in 0 ..< 5 { try r.skipField(try tag(&r)) }
            let last = try tag(&r)
            return (last, try r.readVarint(), r.isAtEnd)
        }
        #expect(last.fieldNumber == 9)
        #expect(value == 42)
        #expect(atEnd)
    }

    @Test func `a group closed by the wrong field number is refused`() {
        var w = WireWriter()
        w.appendTag(5, .startGroup)
        w.appendTag(6, .endGroup)
        let bytes = w.bytes
        #expect(throws: WireError.endGroupMismatch(expected: 5, found: 6, at: 1)) {
            try read(bytes) { r throws(WireError) in try r.skipField(try tag(&r)) }
        }
    }

    @Test func `an end-group with no open group is refused`() {
        var w = WireWriter()
        w.appendTag(5, .endGroup)
        let bytes = w.bytes
        #expect(throws: WireError.unexpectedEndGroup(at: 0)) {
            try read(bytes) { r throws(WireError) in try r.skipField(try tag(&r)) }
        }
    }

    @Test func `a group that never closes is refused`() {
        var w = WireWriter()
        w.appendTag(5, .startGroup)
        w.appendTag(1, .varint)
        w.appendVarint(1)
        let bytes = w.bytes
        #expect(throws: WireError.truncated(at: 3)) {
            try read(bytes) { r throws(WireError) in try r.skipField(try tag(&r)) }
        }
    }

    @Test func `thousands of nested start-groups fail at the depth limit without overflowing the stack`() {
        let bytes = [UInt8](repeating: 0x0B, count: 100_000)  // field 1, start-group, repeated
        #expect(throws: WireError.depthExceeded(limit: 100, at: 100)) {
            try read(bytes) { r throws(WireError) in try r.skipField(try tag(&r)) }
        }
    }

    @Test func `a group inside a message already at the depth limit is refused`() throws {
        var w = WireWriter()
        try w.appendMessage(field: 1) { w throws(WireError) in
            w.appendTag(2, .startGroup)
            w.appendTag(2, .endGroup)
        }
        let bytes = w.bytes
        // Message depth 1 fills the limit of 1; the group would be depth 2. Offset 2 is the group's tag.
        #expect(throws: WireError.depthExceeded(limit: 1, at: 2)) {
            try read(bytes, limits: WireLimits(maxDepth: 1)) { r throws(WireError) in
                _ = try tag(&r)
                try r.readMessage { inner throws(WireError) in try inner.skipField(try tag(&inner)) }
            }
        }
    }

    @Test func `nested messages beyond the depth limit are refused`() throws {
        // Build 4 levels of field-1 messages around a varint, read with a limit of 3.
        var inner = try written {
            $0.appendTag(1, .varint)
            $0.appendVarint(1)
        }
        for _ in 0 ..< 4 {
            let body = inner
            inner = try written { w throws(WireError) in try w.appendMessage(field: 1) { $0.appendRaw(body) } }
        }
        // Explicit nesting: the test must not recurse either (ADR-0006).
        #expect(throws: WireError.depthExceeded(limit: 3, at: 7)) {
            try read(inner, limits: WireLimits(maxDepth: 3)) { r0 throws(WireError) in
                _ = try tag(&r0)
                try r0.readMessage { r1 throws(WireError) in
                    _ = try tag(&r1)
                    try r1.readMessage { r2 throws(WireError) in
                        _ = try tag(&r2)
                        try r2.readMessage { r3 throws(WireError) in
                            _ = try tag(&r3)
                            try r3.readMessage { _ in }
                        }
                    }
                }
            }
        }
    }
}
