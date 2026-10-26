import Testing

@testable import AemiProtobufCore

struct WireSegmentTests {
    @Test func `begin and end write the bytes appendMessage writes`() throws {
        var open = WireWriter()
        let mark = try open.beginMessage(field: 3)
        open.appendTag(1, .varint)
        open.appendVarint(150)
        try open.endMessage(mark)
        let closure = try written { w throws(WireError) in
            try w.appendMessage(field: 3) { w in
                w.appendTag(1, .varint)
                w.appendVarint(150)
            }
        }
        #expect(open.bytes == closure)
    }

    @Test func `a body of 128 bytes widens the length slot when the message is ended`() throws {
        var w = WireWriter()
        let mark = try w.beginMessage(field: 1)
        w.appendRaw([UInt8](repeating: 7, count: 128))
        try w.endMessage(mark)
        #expect(Array(w.bytes.prefix(3)) == [0x0A, 0x80, 0x01])
        #expect(w.bytes.count == 3 + 128)
    }

    @Test func `abandoning a message restores the writer and its depth`() throws {
        var w = WireWriter(limits: WireLimits(maxDepth: 1))
        w.appendTag(9, .varint)
        w.appendVarint(1)
        let before = w.bytes
        let mark = try w.beginMessage(field: 2)
        w.appendRaw([1, 2, 3])
        w.abandonMessage(mark)
        #expect(w.bytes == before)
        // The depth slot was released, so one level is available again.
        let again = try w.beginMessage(field: 2)
        try w.endMessage(again)
        #expect(w.bytes == before + [0x12, 0x00])
    }

    @Test func `beginning past the depth limit is refused and changes nothing`() throws {
        var w = WireWriter(limits: WireLimits(maxDepth: 1))
        _ = try w.beginMessage(field: 1)
        let snapshot = w.bytes
        #expect(throws: WireError.depthExceeded(limit: 1, at: snapshot.count)) { _ = try w.beginMessage(field: 2) }
        #expect(w.bytes == snapshot)
    }

    @Test func `ending an oversized message rolls it back`() throws {
        var w = WireWriter(limits: WireLimits(maxDepth: 4, maxMessageBytes: 2))
        let mark = try w.beginMessage(field: 1)
        w.appendRaw([1, 2, 3])
        #expect(throws: WireError.messageTooLarge(limit: 2)) { try w.endMessage(mark) }
        #expect(w.bytes.isEmpty)
    }

    @Test func `a reader over a sub-range reports absolute offsets and stops at the range end`() throws {
        let bytes: [UInt8] = [0xFF, 0xFF, 0x08, 0x96, 0x01, 0x80, 0xEE]
        let value = try WireReader.withReader(over: bytes, in: 2 ..< 5, depth: 0) { r throws(WireError) in
            let tag = try tag(&r)
            return (tag.fieldNumber.rawValue, try r.readVarint(), r.offset, r.isAtEnd)
        }
        #expect(value == (1, 150, 5, true))
        #expect(throws: WireError.truncated(at: 5)) {
            try WireReader.withReader(over: bytes, in: 5 ..< 6, depth: 0) { r throws(WireError) in
                _ = try r.readVarint()
            }
        }
    }

    @Test func `a reader started at the depth limit refuses a nested message`() throws {
        let bytes: [UInt8] = [0x0A, 0x00]
        let limits = WireLimits(maxDepth: 2)
        #expect(throws: WireError.depthExceeded(limit: 2, at: 1)) {
            try WireReader.withReader(over: bytes, in: 0 ..< 2, depth: 2, limits: limits) { r throws(WireError) in
                _ = try tag(&r)
                try r.readMessage { _ in }
            }
        }
        #expect(throws: WireError.depthExceeded(limit: 2, at: 0)) {
            try WireReader.withReader(over: bytes, in: 0 ..< 2, depth: 3, limits: limits) { _ in }
        }
    }

    @Test func `readPayloadRange returns the payload bytes' range and leaves the reader after it`() throws {
        let bytes: [UInt8] = [0x12, 0x03, 0x61, 0x62, 0x63, 0x20, 0x01]
        let result = try read(bytes) { r throws(WireError) in
            _ = try tag(&r)
            let range = try r.readPayloadRange()
            return (range, r.offset)
        }
        #expect(result.0 == 2 ..< 5)
        #expect(result.1 == 5)
    }

    @Test func `a group skip that failed leaves no state for the next one`() throws {
        // open group 1, close it as group 2 (refused), then a complete group 3
        let bytes: [UInt8] = [0x0B, 0x14, 0x1B, 0x1C]
        let reader: (Bool, Bool) = try read(bytes) { r throws(WireError) in
            let first = try tag(&r)
            var refused = false
            do throws(WireError) { try r.skipField(first) } catch { refused = true }
            let second = try tag(&r)
            var skipped = false
            do throws(WireError) {
                try r.skipField(second)
                skipped = true
            } catch {}
            return (refused, skipped && r.isAtEnd)
        }
        #expect(reader == (true, true))
    }

    @Test func `a string is read from a range that starts at the buffer start`() throws {
        #expect(try WireReader.string(from: [0x68, 0x69, 0x21], in: 0 ..< 2) == "hi")
    }

    @Test func `a string is read from a range and validated`() throws {
        let bytes: [UInt8] = [0x00, 0x68, 0x69, 0xFF, 0xC3, 0xA9]
        #expect(try WireReader.string(from: bytes, in: 1 ..< 3) == "hi")
        #expect(try WireReader.string(from: bytes, in: 4 ..< 6) == "é")
        #expect(try WireReader.string(from: bytes, in: 3 ..< 3) == "")
        #expect(throws: WireError.invalidUTF8(at: 3)) { try WireReader.string(from: bytes, in: 3 ..< 4) }
    }
}
