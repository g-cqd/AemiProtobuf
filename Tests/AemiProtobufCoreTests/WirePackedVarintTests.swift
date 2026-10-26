import Testing

@testable import AemiProtobufCore

struct WirePackedVarintTests {
    private static let wide: [Int64] = [0, 1, -1, 127, 128, -128, 16_383, 16_384, .max, .min, 1 << 35, -(1 << 35)]

    @Test func `packed int64 varints equal the per-element encoding`() throws {
        var bulk = WireWriter()
        bulk.appendPackedVarints(field: 3, Self.wide)
        let each = try written { w throws(WireError) in
            try w.appendMessage(field: 3) { w in for v in Self.wide { w.appendVarint(UInt64(bitPattern: v)) } }
        }
        #expect(bulk.bytes == each)
    }

    @Test func `packed zig-zag varints equal the per-element encoding for 32 and 64 bits`() throws {
        let narrow: [Int32] = [0, 1, -1, .max, .min, 300, -300]
        var bulk = WireWriter()
        bulk.appendPackedVarints(field: 1, narrow, .zigzag)
        bulk.appendPackedVarints(field: 2, Self.wide, .zigzag)
        let each = try written { w throws(WireError) in
            try w.appendMessage(field: 1) { w in for v in narrow { w.appendVarint(UInt64(ZigZag.encode(v))) } }
            try w.appendMessage(field: 2) { w in for v in Self.wide { w.appendVarint(ZigZag.encode(v)) } }
        }
        #expect(bulk.bytes == each)
    }

    @Test func `int32 is sign-extended and uint32 is not`() throws {
        var w = WireWriter()
        w.appendPackedVarints(field: 1, [Int32(-1)])
        w.appendPackedVarints(field: 2, [UInt32.max])
        #expect(
            w.bytes == [0x0A, 0x0A] + [UInt8](repeating: 0xFF, count: 9) + [
                0x01, 0x12, 0x05, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F
            ])
    }

    @Test(arguments: [0, 1, 2, 63, 64, 1_000])
    func `every packed varint type round-trips at every count`(count: Int) throws {
        let signed = (0 ..< count).map { Int64($0 &* 2_654_435_761) &- 1_000_000 }
        let small = signed.map { Int32(truncatingIfNeeded: $0) }
        let unsigned = signed.map { UInt64(bitPattern: $0) }
        let unsigned32 = small.map { UInt32(bitPattern: $0) }
        var w = WireWriter()
        w.appendPackedVarints(field: 1, signed)
        w.appendPackedVarints(field: 2, small)
        w.appendPackedVarints(field: 3, unsigned)
        w.appendPackedVarints(field: 4, unsigned32)
        w.appendPackedVarints(field: 5, signed, .zigzag)
        w.appendPackedVarints(field: 6, small, .zigzag)
        if count == 0 { return #expect(w.bytes.isEmpty) }
        let back = try read(w.bytes) { r throws(WireError) in
            _ = try tag(&r)
            let a = try r.readPackedVarints(Int64.self)
            _ = try tag(&r)
            let b = try r.readPackedVarints(Int32.self)
            _ = try tag(&r)
            let c = try r.readPackedVarints(UInt64.self)
            _ = try tag(&r)
            let d = try r.readPackedVarints(UInt32.self)
            _ = try tag(&r)
            let e = try r.readPackedVarints(Int64.self, .zigzag)
            _ = try tag(&r)
            let f = try r.readPackedVarints(Int32.self, .zigzag)
            return (a, b, c, d, e, f, r.isAtEnd)
        }
        #expect(back.0 == signed && back.1 == small && back.2 == unsigned && back.3 == unsigned32)
        #expect(back.4 == signed && back.5 == small && back.6)
    }

    @Test(arguments: [
        [UInt8]([0x0A, 0x01, 0x80]), [0x0A, 0x03, 0x01, 0x02], [0x0A, 0x0B] + [UInt8](repeating: 0xFF, count: 11)
    ])
    func `a truncated or over-long packed varint is refused`(bytes: [UInt8]) {
        #expect(throws: WireError.self) {
            try read(bytes) { r throws(WireError) in
                _ = try tag(&r)
                _ = try r.readPackedVarints(UInt64.self)
            }
        }
    }
}
