import AemiProtobufSchema
import Foundation
import Testing

struct OneofDescriptorTests {
    private func choice() throws -> (bytes: [UInt8], message: MessageDescriptor) {
        let url = try #require(Bundle.module.url(forResource: "oneof", withExtension: "pb", subdirectory: "Resources"))
        let bytes = [UInt8](try Data(contentsOf: url))
        let set = try FileDescriptorSet.decode(from: bytes)
        return (bytes, try #require(set.files.first?.messages.first))
    }

    @Test func `protoc oneof declarations and membership are decoded`() throws {
        let message = try choice().message
        #expect(message.oneofs.map(\.name) == ["value", "_maybe"])
        #expect(message.fields.map(\.oneofIndex) == [nil, 0, 0, 1])
        #expect(message.fields.map(\.proto3Optional) == [false, false, false, true])
    }

    @Test func `oneof descriptors re-encode to the bytes protoc wrote`() throws {
        let bytes = try choice().bytes
        let set = try FileDescriptorSet.decode(from: bytes)
        #expect(try set.encode() == bytes)
    }

    @Test func `a field naming a missing oneof index is refused`() throws {
        let bad = FileDescriptorSet(files: [
            FileDescriptor(
                name: "x.proto", syntax: "proto3",
                messages: [
                    MessageDescriptor(name: "M", fields: [FieldDescriptor(name: "a", number: 1, oneofIndex: 3)])
                ])
        ])
        let bytes = try bad.encode()
        #expect(throws: DescriptorError.oneofIndexOutOfRange(message: "M", field: "a", index: 3)) {
            try FileDescriptorSet.decode(from: bytes)
        }
    }
}
