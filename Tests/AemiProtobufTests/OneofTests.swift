import AemiProtobuf
import Foundation
import Testing

/// Roadmap 0026: `oneof` as an enumeration with one associated value per member, against protoc.
@Suite struct OneofTests {
    private func decode(_ bytes: [UInt8]) throws -> Shape { try ProtobufDecoder().decode(Shape.self, fromBytes: bytes) }

    @Test(arguments: [
        ("oneof-leaf", Shape(kind: .leaf(Leaf(name: "L")), name: "s")), ("oneof-delta", Shape(kind: .delta(-3))),
        ("oneof-zero", Shape(kind: .circle(0)))
    ])
    func `protoc's bytes decode, and the value encodes to them`(name: String, value: Shape) throws {
        let bytes = try TestResource.bytes(name)
        #expect(try decode(bytes) == value)
        #expect(try ProtobufEncoder().encodeToBytes(value) == bytes)
    }

    @Test func `no member set writes nothing`() throws {
        #expect(try ProtobufEncoder().encodeToBytes(Shape()).isEmpty)
    }

    @Test func `the last member seen wins`() throws {
        #expect(try decode([0x08, 0x05, 0x12, 0x01, 0x78]).kind == .label("x"))
    }

    @Test func `the same message member twice merges, another member in between starts over`() throws {
        // leaf {name: "a"}, then leaf {}
        #expect(try decode([0x1A, 0x03, 0x0A, 0x01, 0x61, 0x1A, 0x00]).kind == .leaf(Leaf(name: "a")))
        // leaf {name: "a"}, circle 1, leaf {}
        #expect(try decode([0x1A, 0x03, 0x0A, 0x01, 0x61, 0x08, 0x01, 0x1A, 0x00]).kind == .leaf(Leaf()))
    }

    @Test func `a closed enumeration member with no case goes to the unknown fields and sets nothing`() throws {
        let decoded = try decode([0x28, 0x09])
        #expect(decoded.kind == nil)
        #expect(decoded.unknownFields.bytes == [0x28, 0x09])
    }

    @Test func `a member with another wire type is unknown, and fields after it are read`() throws {
        let decoded = try decode([0x0D, 0x01, 0x00, 0x00, 0x00, 0x4A, 0x01, 0x73])
        #expect(decoded.kind == nil)
        #expect(decoded.name == "s")
        #expect(decoded.unknownFields.bytes == [0x0D, 0x01, 0x00, 0x00, 0x00])
    }
}
