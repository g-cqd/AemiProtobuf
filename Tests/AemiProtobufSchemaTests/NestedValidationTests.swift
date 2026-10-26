import AemiProtobufCore
import AemiProtobufSchema
import Foundation
import Testing

struct NestedValidationTests {
    private func resource(_ name: String, _ ext: String) throws -> [UInt8] {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources"))
        return [UInt8](try Data(contentsOf: url))
    }

    private func set() throws -> FileDescriptorSet { try FileDescriptorSet.decode(from: try resource("nested", "pb")) }

    @Test func `the bytes protoc wrote for a nested message have no findings at any depth`() throws {
        #expect(
            WireValidator().validate(bytes: try resource("nested", "bin"), against: "p.q.Outer", in: try set()).isEmpty)
    }

    @Test func `a finding in a nested message carries the path of fields to it`() throws {
        let descriptors = try set()
        var deep = WireWriter()
        deep.appendTag(1, .lengthDelimited)
        deep.appendBytes([0xFF])  // not UTF-8
        var inner = WireWriter()
        inner.appendTag(3, .lengthDelimited)
        inner.appendBytes(deep.bytes)
        var outer = WireWriter()
        outer.appendTag(3, .lengthDelimited)
        outer.appendBytes([])  // items[0], fine
        outer.appendTag(3, .lengthDelimited)
        outer.appendBytes(inner.bytes)  // items[1].deep.tag
        let findings = WireValidator().validate(bytes: outer.bytes, against: "p.q.Outer", in: descriptors)
        #expect(findings.count == 1)
        #expect(findings.first?.path == "items[1].deep")
        if case .invalidUTF8(field: 1, at: _)? = findings.first?.error {} else { Issue.record("\(findings)") }
    }

    @Test func `findings come shallowest first and offsets point into the whole buffer`() throws {
        var inner = WireWriter()
        inner.appendTag(2, .fixed32)  // nums must be varint or packed
        inner.appendFixed32(1)
        var outer = WireWriter()
        outer.appendTag(1, .varint)  // name must be length-delimited
        outer.appendVarint(1)
        outer.appendTag(2, .lengthDelimited)
        outer.appendBytes(inner.bytes)
        let findings = WireValidator().validate(bytes: outer.bytes, against: "p.q.Outer", in: try set())
        #expect(findings.map(\.path) == ["", "inner"])
        #expect(findings.last?.error == .unexpectedWireType(field: 2, expected: .varint, actual: .fixed32, at: 5))
    }

    @Test func `a nested message with a malformed packed run is corrupted without hiding its siblings`() throws {
        var bad = WireWriter()
        bad.appendTag(2, .lengthDelimited)
        bad.appendBytes([0x80])  // a varint that never ends
        var outer = WireWriter()
        outer.appendTag(3, .lengthDelimited)
        outer.appendBytes(bad.bytes)
        outer.appendTag(4, .lengthDelimited)
        outer.appendBytes([0x0A, 0x01, 0xFF])  // nested.note is not UTF-8
        let findings = WireValidator().validate(bytes: outer.bytes, against: "p.q.Outer", in: try set())
        #expect(findings.map(\.path) == ["items[0]", "nested"])
    }

    @Test func `type names written relative resolve from the innermost scope outward`() throws {
        let file = FileDescriptor(
            name: "r.proto", package: "p",
            messages: [
                MessageDescriptor(name: "Leaf", fields: [FieldDescriptor(name: "s", number: 1, type: .string)]),
                MessageDescriptor(
                    name: "Outer", fields: [FieldDescriptor(name: "a", number: 1, type: .message, typeName: "Leaf")]),
                MessageDescriptor(
                    name: "Holder", fields: [FieldDescriptor(name: "h", number: 1, type: .message, typeName: "Inner")],
                    nestedMessages: [
                        MessageDescriptor(name: "Inner", fields: [FieldDescriptor(name: "n", number: 1, type: .int32)])
                    ])
            ])
        let set = FileDescriptorSet(files: [file])
        let index = SchemaIndex(set)
        #expect(index.resolve("Leaf", in: "p.Outer") == "p.Leaf")
        #expect(index.resolve("Inner", in: "p.Holder") == "p.Holder.Inner")
        #expect(index.resolve("Inner", in: "p.Outer") == nil)
        #expect(index.resolve(".p.Leaf", in: "anything") == "p.Leaf")
        #expect(index.resolve(".p.Nope", in: "p") == nil)
        // a bad string in the relatively-named Leaf is found through the resolved name
        let bytes: [UInt8] = [0x0A, 0x03, 0x0A, 0x01, 0xFF]
        let findings = WireValidator().validate(bytes: bytes, against: "p.Outer", in: set)
        #expect(findings.map(\.path) == ["a"])
    }

    @Test func `an unknown root message and an unresolved field type are findings`() throws {
        #expect(
            WireValidator().validate(bytes: [], against: "p.q.Nope", in: try set()) == [
                WireFinding(path: "", error: .unknownMessage("p.q.Nope"))
            ])
        var broken = try set()
        broken.files[0].messages[2].fields[1].typeName = ".p.q.Missing"
        let findings = WireValidator()
            .validate(
                bytes: [0x12, 0x00], against: "p.q.Outer", in: broken)
        #expect(findings == [WireFinding(path: "inner", error: .unresolvedType(field: 2, typeName: ".p.q.Missing"))])
    }

    @Test func `nesting beyond the depth limit is a finding and the stack is never used for it`() {
        let depth = 2_000
        let message = MessageDescriptor(
            name: "Node", fields: [FieldDescriptor(name: "next", number: 1, type: .message, typeName: ".Node")])
        let set = FileDescriptorSet(files: [FileDescriptor(name: "n.proto", messages: [message])])
        var bytes: [UInt8] = []
        for _ in 0 ..< depth {
            var w = WireWriter(limits: WireLimits(maxDepth: .max))
            w.appendTag(1, .lengthDelimited)
            w.appendBytes(bytes)
            bytes = w.bytes
        }
        let findings = WireValidator().validate(bytes: bytes, against: "Node", in: set)
        #expect(findings.count == 1)
        if case .wireCorrupted(.depthExceeded(limit: 100, at: _))? = findings.first?.error {
        } else {
            Issue.record("\(findings)")
        }
    }

    @Test func `the finding cap holds across messages`() throws {
        var outer = WireWriter()
        for _ in 0 ..< 50 {
            outer.appendTag(3, .lengthDelimited)
            outer.appendBytes([0x0A, 0x01, 0xFF])  // items[i].label is not UTF-8
        }
        let findings = WireValidator(maxFindings: 5).validate(bytes: outer.bytes, against: "p.q.Outer", in: try set())
        #expect(findings.count == 6)
        #expect(findings.last?.error == .findingLimitReached)
    }

    @Test func `required fields are checked in nested messages`() {
        let file = FileDescriptor(
            name: "q.proto",
            messages: [
                MessageDescriptor(
                    name: "Inner", fields: [FieldDescriptor(name: "id", number: 1, label: .required, type: .int32)]),
                MessageDescriptor(
                    name: "Outer", fields: [FieldDescriptor(name: "i", number: 1, type: .message, typeName: "Inner")])
            ])
        let findings = WireValidator()
            .validate(
                bytes: [0x0A, 0x00], against: "Outer", in: FileDescriptorSet(files: [file]))
        #expect(findings == [WireFinding(path: "i", error: .requiredFieldMissing(field: 1, name: "id"))])
    }
}
