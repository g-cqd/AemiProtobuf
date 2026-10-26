import Testing

@testable import AemiProtobufCore

/// The reader walked over bytes `protoc` 36.2 produced, checked against what `protoc --decode_raw` printed for them.
struct WireOracleTests {
    // protoc --encode=User < sample.txt (docs/research/probes/aepb-throughput).
    static let sample = hex(
        "08 96 01 12 03 61 6e 6e 1a 05 61 40 62 2e 63 20 01 29 00 00 00 00 00 00 f8 3f 32 01 78 32 01 79 "
            + "3a 0d 01 ac 02 ff ff ff ff ff ff ff ff ff 01 42 08 0a 01 73 12 01 63 18 07 48 05 51 09 00 00 00 00 00 00 00"
    )

    @Test func `the reader lists the fields that protoc --decode_raw lists`() throws {
        var lines: [String] = []
        try read(Self.sample) { r throws(WireError) in
            while let tag = try r.nextTag() {
                let n = tag.fieldNumber.rawValue
                switch tag.wireType {
                    case .varint: lines.append("\(n): \(try r.readVarint())")
                    case .fixed64: lines.append("\(n): 0x\(String(try r.readFixed64(), radix: 16))")
                    case .lengthDelimited: lines.append("\(n): \(try r.readBytes().count) bytes")
                    case .fixed32, .startGroup, .endGroup: lines.append("unexpected wire type")
                }
            }
        }
        // decode_raw: 1: 150 | 2: "ann" | 3: "a@b.c" | 4: 1 | 5: 0x3ff8000000000000 | 6: "x" | 6: "y" | 7: 13 packed bytes
        // | 8 { 1: "s" 2: "c" 3: 7 } (8 bytes) | 9: 5 | 10: 0x9
        #expect(
            lines == [
                "1: 150", "2: 3 bytes", "3: 5 bytes", "4: 1", "5: 0x3ff8000000000000", "6: 1 bytes", "6: 1 bytes",
                "7: 13 bytes", "8: 8 bytes", "9: 5", "10: 0x9"
            ])
    }

    @Test func `the packed field decodes to 1, 300 and -1`() throws {
        var values: [Int32] = []
        try read(Self.sample) { r throws(WireError) in
            while let tag = try r.nextTag() {
                if tag.fieldNumber == 7 {
                    try r.readMessage { r throws(WireError) in
                        while !r.isAtEnd { values.append(try r.readInt32()) }
                    }
                } else {
                    try r.skipField(tag)
                }
            }
        }
        #expect(values == [1, 300, -1])
    }

    @Test func `a nested message and a zig-zag field read correctly from the oracle bytes`() throws {
        var street = ""
        var delta: Int32 = 0
        try read(Self.sample) { r throws(WireError) in
            while let tag = try r.nextTag() {
                switch tag.fieldNumber.rawValue {
                    case 8:
                        try r.readMessage { r throws(WireError) in
                            if let t = try r.nextTag(), t.fieldNumber == 1 { street = try r.readString() }
                        }
                    case 9: delta = ZigZag.decode(UInt32(truncatingIfNeeded: try r.readVarint()))
                    default: try r.skipField(tag)
                }
            }
        }
        #expect(street == "s")
        #expect(delta == -3)  // protoc: `delta: -3` printed as `9: 5`
    }
}
