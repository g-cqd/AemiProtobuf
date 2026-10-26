# AemiProtobuf

Protocol Buffers for Swift 6, for high-performance API communication. The shape follows AemiJSON: a Foundation-free engine, a
Codable surface, a macro fast path, and tools for definition and checking.

**Status: the wire core, the `@ProtoMessage` macro, the coders, descriptors, a `.proto` subset parser and wire validation are built;
the rest is planned.** See `docs/DESIGN.md` for the plan, `docs/roadmap/` for the order, and
`docs/research/2026-10-25-aemijson-vs-aemiprotobuf.md` for measurements against AemiJSON and swift-protobuf.

```swift
import AemiProtobuf

@ProtoMessage
struct User {
    @ProtoField(1) var id: Int64 = 0
    @ProtoField(2) var name: String = ""
    @ProtoField(3, .sint32) var delta: Int32 = 0
    @ProtoField(4) var tags: [String] = []
}

let bytes = try ProtobufEncoder().encodeToBytes(User(id: 150, name: "ann"))
let user = try ProtobufDecoder().decode(User.self, fromBytes: bytes)
```

The wire core underneath, for code that wants no coder:

```swift
import AemiProtobufCore

var writer = WireWriter()
writer.appendTag(1, .varint)
writer.appendVarint(150)
writer.appendTag(2, .lengthDelimited)
writer.appendString("testing")
// writer.bytes == 08 96 01 12 07 74 65 73 74 69 6e 67

try WireReader.withReader(over: writer.bytes) { reader throws(WireError) in
    while let tag = try reader.nextTag() {
        switch (tag.fieldNumber, tag.wireType) {
        case (1, .varint): print(try reader.readVarint())
        case (2, .lengthDelimited): print(try reader.readString())
        default: try reader.skipField(tag)  // unknown fields are skipped, groups included
        }
    }
}
```

Requirements: Swift 6.4 toolchain; macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2.

MIT.
