import AemiKernel
import Testing

@testable import AemiProtobufCore

struct WireWriterTests {
    @Test func `a nested message of 200 bytes gets a two-byte length, as protoc writes it`() throws {
        // protoc 36.2: `address { street: "x" * 200 }` on User is 42 cb 01 0a c8 01 78...78 (206 bytes).
        let street = String(repeating: "x", count: 200)
        let bytes = try written { w throws(WireError) in
            try w.appendMessage(field: 8) { w throws(WireError) in
                w.appendTag(1, .lengthDelimited)
                w.appendString(street)
            }
        }
        #expect(bytes.count == 206)
        #expect(Array(bytes.prefix(6)) == hex("42 cb 01 0a c8 01"))
        #expect(bytes.dropFirst(6).allSatisfy { $0 == 0x78 })
    }

    @Test(arguments: [0, 1, 126, 127, 128, 16_382, 16_383, 16_384, 70_000])
    func `the length prefix is minimal at every varint size boundary`(payload: Int) throws {
        let body = [UInt8](repeating: 0xAB, count: payload)
        let bytes = try written { w throws(WireError) in
            try w.appendMessage(field: 2) { $0.appendRaw(body) }
        }
        var expected: [UInt8] = [0x12]  // field 2, length-delimited
        Varint.append(UInt64(payload), to: &expected)  // the independent kernel computes the prefix
        expected += body
        #expect(bytes == expected)
    }

    @Test func `an empty nested message is a tag and a zero length`() throws {
        #expect(try written { w throws(WireError) in try w.appendMessage(field: 1) { _ in } } == hex("0a 00"))
    }

    @Test func `nested messages round-trip through the reader`() throws {
        let bytes = try written { w throws(WireError) in
            try w.appendMessage(field: 1) { w throws(WireError) in
                w.appendTag(1, .varint)
                w.appendVarint(150)
                try w.appendMessage(field: 2) { w in
                    w.appendTag(1, .lengthDelimited)
                    w.appendString("deep")
                }
            }
        }
        var seen: [String] = []
        try read(bytes) { r throws(WireError) in
            seen.append("\(try tag(&r).rawValue)")
            try r.readMessage { r throws(WireError) in
                _ = try tag(&r)
                seen.append("\(try r.readVarint())")
                _ = try tag(&r)
                try r.readMessage { r throws(WireError) in
                    _ = try tag(&r)
                    seen.append(try r.readString())
                    seen.append("end:\(r.isAtEnd)")
                }
            }
            seen.append("end:\(r.isAtEnd)")
        }
        #expect(seen == ["10", "150", "deep", "end:true", "end:true"])
    }

    @Test func `a message exactly at the size limit is written`() throws {
        var w = WireWriter(limits: WireLimits(maxMessageBytes: 10))
        try w.appendMessage(field: 2) { $0.appendRaw([UInt8](repeating: 7, count: 10)) }
        #expect(w.bytes == [0x12, 10] + [UInt8](repeating: 7, count: 10))
    }

    @Test func `bytes fields keep their contents and their length`() throws {
        let payload: [UInt8] = [0, 1, 2, 0xFF, 0x80]
        let bytes = try written { $0.appendBytes(payload) }
        #expect(bytes == [5] + payload)
        let back = try read(bytes) { r throws(WireError) in try r.readBytes() }
        #expect(back == payload)
    }

    @Test func `a message over the size limit is refused and leaves the writer as it was`() throws {
        var w = WireWriter(limits: WireLimits(maxMessageBytes: 10))
        w.appendTag(1, .varint)
        w.appendVarint(1)
        let before = w.bytes
        #expect(throws: WireError.messageTooLarge(limit: 10)) {
            try w.appendMessage(field: 2) { $0.appendRaw([UInt8](repeating: 0, count: 20)) }
        }
        #expect(w.bytes == before)
    }

    @Test func `a body that throws leaves the writer as it was`() throws {
        var w = WireWriter()
        w.appendTag(1, .varint)
        w.appendVarint(1)
        let before = w.bytes
        #expect(throws: WireError.invalidUTF8(at: 99)) {
            try w.appendMessage(field: 2) { w throws(WireError) in
                w.appendVarint(5)
                throw .invalidUTF8(at: 99)
            }
        }
        #expect(w.bytes == before)
    }

    @Test func `writing nested messages past the depth limit is refused`() {
        var w = WireWriter(limits: WireLimits(maxDepth: 2))
        #expect(throws: WireError.depthExceeded(limit: 2, at: 4)) {
            try w.appendMessage(field: 1) { w throws(WireError) in
                try w.appendMessage(field: 1) { w throws(WireError) in
                    try w.appendMessage(field: 1) { _ in }
                }
            }
        }
        #expect(w.bytes.isEmpty)
    }

    @Test func `the README example writes and reads back the encoding guide's message`() throws {
        var writer = WireWriter()
        writer.appendTag(1, .varint)
        writer.appendVarint(150)
        writer.appendTag(2, .lengthDelimited)
        writer.appendString("testing")
        #expect(writer.bytes == hex("08 96 01 12 07 74 65 73 74 69 6e 67"))
        var seen: [String] = []
        try WireReader.withReader(over: writer.bytes) { reader throws(WireError) in
            while let tag = try reader.nextTag() {
                switch (tag.fieldNumber, tag.wireType) {
                    case (1, .varint): seen.append("\(try reader.readVarint())")
                    case (2, .lengthDelimited): seen.append(try reader.readString())
                    default: try reader.skipField(tag)
                }
            }
        }
        #expect(seen == ["150", "testing"])
    }

    @Test func `the writer reproduces the bytes protoc wrote for a full message`() throws {
        // protoc 36.2 --encode=User for the message in docs/research/probes (ids, strings, packed int32, nested, sint32).
        let expected = hex(
            "08 96 01 12 03 61 6e 6e 1a 05 61 40 62 2e 63 20 01 29 00 00 00 00 00 00 f8 3f 32 01 78 32 01 79 "
                + "3a 0d 01 ac 02 ff ff ff ff ff ff ff ff ff 01 42 08 0a 01 73 12 01 63 18 07 48 05 51 09 00 00 00 00 00 00 00"
        )
        let bytes = try written { w throws(WireError) in
            w.appendTag(1, .varint)
            w.appendVarint(150)
            w.appendTag(2, .lengthDelimited)
            w.appendString("ann")
            w.appendTag(3, .lengthDelimited)
            w.appendString("a@b.c")
            w.appendTag(4, .varint)
            w.appendVarint(1)
            w.appendTag(5, .fixed64)
            w.appendDouble(1.5)
            w.appendTag(6, .lengthDelimited)
            w.appendString("x")
            w.appendTag(6, .lengthDelimited)
            w.appendString("y")
            try w.appendMessage(field: 7) { w in  // packed int32: 1, 300, -1
                w.appendInt32(1)
                w.appendInt32(300)
                w.appendInt32(-1)
            }
            try w.appendMessage(field: 8) { w in
                w.appendTag(1, .lengthDelimited)
                w.appendString("s")
                w.appendTag(2, .lengthDelimited)
                w.appendString("c")
                w.appendTag(3, .varint)
                w.appendVarint(7)
            }
            w.appendTag(9, .varint)
            w.appendVarint(UInt64(ZigZag.encode(Int32(-3))))
            w.appendTag(10, .fixed64)
            w.appendFixed64(9)
        }
        #expect(bytes == expected)
    }
}
