import AemiProtobufCore
import Testing

/// Roadmap 0027: reading and writing a group as a nested message.
@Suite struct WireGroupTests {
    @Test func `a group is written between its tags, and one that throws leaves nothing`() throws {
        var writer = WireWriter()
        try writer.appendGroup(field: 2) { w throws(WireError) in
            w.appendTag(1, .varint)
            w.appendVarint(5)
        }
        #expect(writer.bytes == [0x13, 0x08, 0x05, 0x14])
        #expect(throws: WireError.self) {
            try writer.appendGroup(field: 3) { _ throws(WireError) in throw .truncated(at: 0) }
        }
        #expect(writer.bytes == [0x13, 0x08, 0x05, 0x14])
    }

    @Test func `the group's reader sees its fields, nested groups included, and the outer reader continues after it`()
        throws
    {
        // group 2 { 1: 5, group 3 { 1: 6 } }, then 4: 7
        let bytes: [UInt8] = [0x13, 0x08, 0x05, 0x1B, 0x08, 0x06, 0x1C, 0x14, 0x20, 0x07]
        let (inner, after) = try WireReader.withReader(over: bytes) { r throws(WireError) -> ([UInt8], UInt64) in
            guard let tag = try r.nextTag() else { throw .truncated(at: 0) }
            let seen = try r.readGroup(tag) { g throws(WireError) -> [UInt8] in
                var tags: [UInt8] = []
                while let t = try g.nextTag() {
                    tags.append(UInt8(t.fieldNumber.rawValue))
                    try g.skipField(t)
                }
                return tags
            }
            _ = try r.nextTag()
            return (seen, try r.readVarint())
        }
        #expect(inner == [1, 3])
        #expect(after == 7)
    }

    @Test func `nesting past the limit is refused, writing and reading`() throws {
        var writer = WireWriter(limits: WireLimits(maxDepth: 1))
        #expect(throws: WireError.self) {
            try writer.appendGroup(field: 1) { w throws(WireError) in
                try w.appendGroup(field: 2) { _ throws(WireError) in }
            }
        }
        #expect(writer.bytes.isEmpty)
        let bytes: [UInt8] = [0x0B, 0x13, 0x14, 0x0C]
        #expect(throws: WireError.self) {
            try WireReader.withReader(over: bytes, limits: WireLimits(maxDepth: 1)) { r throws(WireError) in
                guard let tag = try r.nextTag() else { return }
                try r.readGroup(tag) { g throws(WireError) in
                    guard let inner = try g.nextTag() else { return }
                    try g.readGroup(inner) { _ throws(WireError) in }
                }
            }
        }
    }
}
