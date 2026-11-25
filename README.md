# AemiProtobuf

Protocol Buffers for Swift 6: a Foundation-free wire reader and writer, a `@ProtoMessage` macro fast path, Codable coders, `.proto` schema descriptors, ProtoJSON, and code-generation/validation tools.

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

Low-level wire access without Codable:

```swift
import AemiProtobufCore

var writer = WireWriter()
writer.appendTag(1, .varint)
writer.appendVarint(150)
writer.appendTag(2, .lengthDelimited)
writer.appendString("testing")
```

## Requirements

- Swift 6.4+ (Swift 6 language mode)
- macOS 15+, iOS 18+, tvOS 18+, watchOS 11+, visionOS 2+, or Linux

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/g-cqd/AemiProtobuf.git", branch: "main")
]
```

## Products

| Product | Description |
| --- | --- |
| `AemiProtobufCore` | Bounds-checked wire reader/writer, ZigZag, varints, zero Foundation dependency |
| `AemiProtobuf` | `@ProtoMessage` / `@ProtoField` macros, `ProtobufEncoder`, `ProtobufDecoder` |
| `AemiProtobufSchema` | `.proto` parser, descriptors, wire validation |
| `AemiProtobufJSON` | Canonical ProtoJSON mapping built on `AemiJSONCore` |
| `AemiProtobufGenerator` | Swift code generator from `.proto` descriptors |
| `protoc-gen-aemi` | `protoc` plugin executable |
| `aemi-proto-check` / `ProtobufCheck` | Wire/schema verification CLI and SwiftPM plugin |

## Documentation

- [Architecture Decisions](docs/adr/)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)

## License

[MIT](LICENSE)
