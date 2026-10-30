import AemiProtobufSchema
import Foundation
import Testing

struct ProtoParserOneofTests {
    private func resource(_ name: String, _ ext: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources"))
        return try Data(contentsOf: url)
    }

    @Test func `parsed oneof and proto3 optional equal what protoc produced`() throws {
        let source = String(decoding: try resource("oneof", "proto"), as: UTF8.self)
        let expected = try #require(
            try FileDescriptorSet.decode(from: [UInt8](try resource("oneof", "pb"))).files.first)
        let parsed = try ProtoParser().parse(source, name: "oneof.proto")
        #expect(parsed == expected)
    }

    @Test(arguments: [
        ("snake_case_name", "snakeCaseName"), ("a", "a"), ("a_b", "aB"), ("a__b", "aB"), ("x_1", "x1"),
        ("trail_", "trail")
    ])
    func `json names follow protoc camel casing`(name: String, json: String) throws {
        // Without `syntax`, a file is proto2 (as protoc reads it), where a field needs a label.
        let file = try ProtoParser().parse("syntax = \"proto3\"; message M { int32 \(name) = 1; }")
        #expect(file.messages.first?.fields.first?.jsonName == json)
    }

    @Test(arguments: [
        "message M { oneof { int32 a = 1; } }",
        "message M { oneof o { } }",
        "message M { oneof o { repeated int32 a = 1; } }",
        "message M { oneof o { oneof p { int32 a = 1; } } }",
        "message M { oneof o { int32 a = 1;",
        "message M { optional int32 a = 1; }" + " message N { oneof o { optional int32 b = 1; } }"
    ])
    func `malformed oneof declarations are refused`(source: String) {
        let proto3 = "syntax = \"proto3\"; " + source
        #expect(throws: ProtoParseError.self) { try ProtoParser().parse(proto3) }
    }
}
