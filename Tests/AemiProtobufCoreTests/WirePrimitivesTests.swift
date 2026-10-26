import AemiKernel
import Testing

@testable import AemiProtobufCore

/// Vectors in this file come from the protobuf encoding guide and from `protoc` 36.2, not from the code under test.
struct WirePrimitivesTests {
    @Test(
        arguments: [
            (UInt64(0), "00"), (1, "01"), (127, "7f"), (128, "80 01"), (150, "96 01"), (300, "ac 02"),
            (16_383, "ff 7f"), (16_384, "80 80 01"), (UInt64(UInt32.max), "ff ff ff ff 0f"),
            (UInt64.max, "ff ff ff ff ff ff ff ff ff 01")
        ] as [(UInt64, String)])
    func `varint encodes to the documented bytes and reads back`(value: UInt64, encoded: String) throws {
        let bytes = try written { $0.appendVarint(value) }
        #expect(bytes == hex(encoded))
        let back = try read(bytes) { r throws(WireError) in try r.readVarint() }
        #expect(back == value)
    }

    @Test func `a negative int32 is sign-extended to ten bytes`() throws {
        let bytes = try written { $0.appendInt32(-1) }
        #expect(bytes == hex("ff ff ff ff ff ff ff ff ff 01"))
        let back = try read(bytes) { r throws(WireError) in try r.readInt32() }
        #expect(back == -1)
    }

    @Test(
        arguments: [
            (Int32(0), UInt32(0)), (Int32(-1), UInt32(1)), (Int32(1), UInt32(2)), (Int32(-2), UInt32(3)),
            (Int32.max, UInt32(4_294_967_294)), (Int32.min, UInt32(4_294_967_295))
        ] as [(Int32, UInt32)])
    func `zig-zag maps 32-bit values as the encoding guide lists`(value: Int32, mapped: UInt32) {
        #expect(ZigZag.encode(value) == mapped)
        #expect(ZigZag.decode(mapped) == value)
    }

    @Test(
        arguments: [
            (Int64(0), UInt64(0)), (Int64(-1), UInt64(1)), (Int64(1), UInt64(2)), (Int64.max, UInt64.max - 1),
            (Int64.min, UInt64.max)
        ] as [(Int64, UInt64)])
    func `zig-zag maps 64-bit values as the encoding guide lists`(value: Int64, mapped: UInt64) {
        #expect(ZigZag.encode(value) == mapped)
        #expect(ZigZag.decode(mapped) == value)
    }

    /// `Models/lean/AemiProtobufModels/Varint.lean` proves `width_le_ten` and the encode/decode round trip for every natural number;
    /// this checks that the Swift width formula agrees with the independent kernel encoder at every bit boundary.
    @Test func `the varint width formula matches the kernel encoder at every bit boundary`() {
        var values: [UInt64] = [0, UInt64.max]
        for bit in 0 ..< 64 {
            values += [UInt64(1) << UInt64(bit), (UInt64(1) << UInt64(bit)) &- 1, (UInt64(1) << UInt64(bit)) &+ 1]
        }
        for value in values {
            var encoded: [UInt8] = []
            Varint.append(value, to: &encoded)
            #expect(WireWriter.varintWidth(value) == encoded.count, "value \(value)")
        }
    }

    @Test func `fixed32 and fixed64 are little-endian`() throws {
        let bytes = try written {
            $0.appendFixed32(0x0102_0304)
            $0.appendFixed64(0x0102_0304_0506_0708)
        }
        #expect(bytes == hex("04 03 02 01 08 07 06 05 04 03 02 01"))
        let (a, b, atEnd) = try read(bytes) { r throws(WireError) in
            (try r.readFixed32(), try r.readFixed64(), r.isAtEnd)
        }
        #expect(a == 0x0102_0304)
        #expect(b == 0x0102_0304_0506_0708)
        #expect(atEnd)
    }

    @Test func `a double is its IEEE bit pattern in fixed64`() throws {
        let bytes = try written { $0.appendDouble(1.5) }
        #expect(bytes == hex("00 00 00 00 00 00 f8 3f"))  // protoc: `score: 1.5` is 0x3ff8000000000000
        let back = try read(bytes) { r throws(WireError) in try r.readDouble() }
        #expect(back == 1.5)
    }

    @Test func `field numbers accept 1 through 2^29-1 and nothing else`() {
        #expect(FieldNumber(rawValue: 0) == nil)
        #expect(FieldNumber(rawValue: 1)?.rawValue == 1)
        #expect(FieldNumber(rawValue: 536_870_911)?.rawValue == 536_870_911)
        #expect(FieldNumber(rawValue: 536_870_912) == nil)
    }

    @Test func `field numbers order by value`() {
        #expect(FieldNumber(rawValue: 1)! < FieldNumber(rawValue: 2)!)
        #expect(!(FieldNumber(rawValue: 2)! < FieldNumber(rawValue: 1)!))
        #expect(!(FieldNumber(rawValue: 2)! < FieldNumber(rawValue: 2)!))
    }

    @Test func `a tag packs the field number above the wire type`() throws {
        let tag = FieldTag(fieldNumber: 1, wireType: .varint)
        #expect(tag.rawValue == 0x08)  // the guide: field 1, varint, is 08
        let largest = FieldTag(fieldNumber: FieldNumber(rawValue: 536_870_911)!, wireType: .fixed32)
        #expect(largest.rawValue == 0xFFFF_FFFD)
        #expect(try FieldTag(rawValue: UInt64(largest.rawValue), at: 0) == largest)
    }

    @Test(
        arguments: [
            (UInt64(0), WireError.invalidTag(0, at: 7)), (0x0E, .invalidWireType(6, at: 7)),
            (0x0F, .invalidWireType(7, at: 7)), (0xFFFF_FFFF, .invalidWireType(7, at: 7)),
            (0x1_0000_0008, .invalidTag(0x1_0000_0008, at: 7))
        ] as [(UInt64, WireError)])
    func `a malformed tag is refused with its offset`(raw: UInt64, expected: WireError) {
        #expect(throws: expected) { _ = try FieldTag(rawValue: raw, at: 7) }
    }

    @Test func `random scalars written then read back are identical`() throws {
        var rng = SplitMix64(state: 0xA3E1)
        let values = (0 ..< 500).map { _ in rng.next() >> UInt64.random(in: 0 ..< 64, using: &rng) }
        let bytes = try written { w in
            for v in values {
                w.appendVarint(v)
                w.appendFixed64(v)
            }
        }
        let back = try read(bytes) { r throws(WireError) in
            var out: [(UInt64, UInt64)] = []
            for _ in values { out.append((try r.readVarint(), try r.readFixed64())) }
            return (out, r.isAtEnd)
        }
        #expect(back.0.map(\.0) == values)
        #expect(back.0.map(\.1) == values)
        #expect(back.1)
    }
}
