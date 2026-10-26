import AemiProtobufSchema
import Foundation
import Testing

struct ProtoParserTests {
    @Test func `parse .proto text matches structure from protoc descriptor`() throws {
        let url = try #require(
            Bundle.module.url(forResource: "sample", withExtension: "proto", subdirectory: "Resources"))
        let text = try String(contentsOf: url, encoding: .utf8)

        let parser = ProtoParser()
        let file = try parser.parse(text, name: "sample.proto")

        #expect(file.syntax == "proto3")
        #expect(file.package == "test.sample")
        #expect(file.messages.count == 2)

        let user = file.messages.first { $0.name == "User" }
        #expect(user != nil)
        #expect(user?.fields.count == 10)

        let idField = user?.fields.first { $0.name == "id" }
        #expect(idField?.number == 1)
        #expect(idField?.type == .int64)

        let tagsField = user?.fields.first { $0.name == "tags" }
        #expect(tagsField?.label == .repeated)
        #expect(tagsField?.type == .string)

        let addrField = user?.fields.first { $0.name == "address" }
        #expect(addrField?.type == .message)
        #expect(addrField?.typeName == "Address")

        let deltaField = user?.fields.first { $0.name == "delta" }
        #expect(deltaField?.type == .sint32)

        let stampField = user?.fields.first { $0.name == "stamp" }
        #expect(stampField?.type == .fixed64)
    }
}
