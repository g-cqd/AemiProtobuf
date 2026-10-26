import Testing

@testable import AemiProtobufCore

struct WireBulkTests {
    @Test func `packed doubles are written as one record of little-endian words`() throws {
        var w = WireWriter()
        w.appendPackedLittleEndian(field: 2, [1.0, -2.5])
        let expected = try written { w throws(WireError) in
            try w.appendMessage(field: 2) { w in
                w.appendDouble(1.0)
                w.appendDouble(-2.5)
            }
        }
        #expect(w.bytes == expected)
    }

    @Test(arguments: [0, 1, 7, 1_000])
    func `packed values of every width round-trip and an empty array writes nothing`(count: Int) throws {
        let ints = (0 ..< count).map { Int32(truncatingIfNeeded: $0 &* 2_654_435_761) }
        let longs = (0 ..< count).map { Int64($0) &* -3_000_000_007 }
        var w = WireWriter()
        w.appendPackedLittleEndian(field: 1, ints)
        w.appendPackedLittleEndian(field: 2, longs)
        if count == 0 {
            #expect(w.bytes.isEmpty)
            return
        }
        let back = try read(w.bytes) { r throws(WireError) in
            _ = try tag(&r)
            let a = try r.readPackedLittleEndian(Int32.self)
            _ = try tag(&r)
            let b = try r.readPackedLittleEndian(Int64.self)
            return (a, b, r.isAtEnd)
        }
        #expect(back.0 == ints)
        #expect(back.1 == longs)
        #expect(back.2)
    }

    @Test(arguments: [1, 3, 5, 7])
    func `a packed record whose length is not a multiple of the width is refused`(length: Int) {
        let bytes = [UInt8(0x0A), UInt8(length)] + [UInt8](repeating: 1, count: length)
        #expect(throws: WireError.self) {
            try read(bytes) { r throws(WireError) in
                _ = try tag(&r)
                _ = try r.readPackedLittleEndian(Int64.self)
            }
        }
    }

    @Test func `a packed record longer than the bytes that remain is refused`() {
        #expect(throws: WireError.lengthOutOfBounds(declared: 16, remaining: 3, at: 1)) {
            try read([0x0A, 0x10, 1, 2, 3]) { r throws(WireError) in
                _ = try tag(&r)
                _ = try r.readPackedLittleEndian(Double.self)
            }
        }
    }

    @Test func `readPayload reads a length-delimited scope without costing a nesting level`() throws {
        let limits = WireLimits(maxDepth: 0)
        let sum = try read([0x0A, 0x02, 0x01, 0x02], limits: limits) { r throws(WireError) in
            _ = try tag(&r)
            return try r.readPayload { r throws(WireError) in try r.readVarint() + r.readVarint() }
        }
        #expect(sum == 3)
        #expect(throws: WireError.depthExceeded(limit: 0, at: 1)) {
            try read([0x0A, 0x00], limits: limits) { r throws(WireError) in
                _ = try tag(&r)
                try r.readMessage { _ in }
            }
        }
    }

    @Test func `the varint count of a packed run is the number of terminating bytes`() throws {
        let count = try read([0x0A, 0x06, 0x01, 0x80, 0x01, 0xFF, 0xFF, 0x7F]) { r throws(WireError) in
            _ = try tag(&r)
            return try r.readPayload { r throws(WireError) in r.remainingVarintCount }
        }
        #expect(count == 3)
    }

    @Test func `reserve grows geometrically and not at all when there is room`() {
        var w = WireWriter(reservingCapacity: 64)
        let capacity = w.bytes.capacity
        w.reserve(additional: 10)
        #expect(w.bytes.capacity == capacity)
        w.reserve(additional: capacity)  // fits exactly: no growth
        #expect(w.bytes.capacity == capacity)
        w.reserve(additional: capacity + 1)  // one byte over: at least doubles, so repeated calls are amortised
        #expect(w.bytes.capacity >= capacity * 2)
        w.reserve(additional: capacity * 10)
        #expect(w.bytes.capacity >= capacity * 10)
    }

    @Test(arguments: [0, 1, 3, 7, 8, 9, 15, 16, 17, 31, 64, 101])
    func `the varint count equals a byte-by-byte count at every length and alignment`(length: Int) throws {
        // mostly continuation bytes with few terminators, so counting the wrong kind of byte gives a different number
        let payload: [UInt8] = (0 ..< length).map { $0 % 5 == 0 ? UInt8(0x01) : UInt8(0xC0 | ($0 & 0x3F)) }
        let expected = payload.filter { $0 < 0x80 }.count
        let bytes = [0x0A] + (try written { w throws(WireError) in w.appendVarint(UInt64(length)) }) + payload
        let count = try read(bytes) { r throws(WireError) in
            _ = try tag(&r)
            return try r.readPayload { r throws(WireError) in r.remainingVarintCount }
        }
        #expect(count == expected)
    }

    @Test func `a one-byte varint and a tag write the same bytes as before`() {
        var w = WireWriter()
        w.appendVarint(0x7F)
        w.appendVarint(0x80)
        w.appendTag(15, .varint)
        w.appendTag(16, .varint)
        #expect(w.bytes == [0x7F, 0x80, 0x01, 0x78, 0x80, 0x01])
    }
}
