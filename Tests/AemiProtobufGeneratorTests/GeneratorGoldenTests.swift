import AemiProtobufCore
import AemiProtobufGenerator
import AemiProtobufSchema
import Foundation
import Testing

/// Roadmap 0028: regenerating the test protos gives exactly the committed `Tests/AemiProtobufGeneratedTests/Generated*.swift`,
/// which that target compiles and checks against protoc's bytes. A change to the generator shows up here as a diff to commit.
@Suite struct GeneratorGoldenTests {
    private static let generated = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "AemiProtobufGeneratedTests")

    private func set(_ name: String) throws -> FileDescriptorSet {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "pb", subdirectory: "Resources"))
        return try FileDescriptorSet.decode(from: [UInt8](try Data(contentsOf: url)))
    }

    @Test(arguments: ["kinds", "maps", "oneof", "proto2", "packed", "merge"])
    func `the generator writes the committed file`(name: String) throws {
        let files = try SwiftGenerator.generate(set(name), files: ["\(name).proto"])
        #expect(files.map(\.name) == ["\(name).aemi.swift"])
        let golden = Self.generated.appending(path: "Generated\(name.prefix(1).uppercased() + name.dropFirst()).swift")
        let committed = try String(contentsOf: golden, encoding: .utf8)
        #expect(files.first?.content == committed, "regenerate with Scripts/generate-test-protos.sh")
    }

    @Test func `public visibility makes every declaration and an initializer public`() throws {
        var options = GeneratorOptions()
        options.visibility = .public
        let content = try #require(
            SwiftGenerator.generate(set("oneof"), files: ["oneof.proto"], options: options).first
        )
        .content
        #expect(content.contains("public struct Gen_Oneof_Shape"))
        #expect(content.contains("@ProtoOneofField public var kind"))
        #expect(content.contains("public init() {}"))
        #expect(content.contains("public enum OneOf_Kind"))
    }

    @Test func `options parse from protoc's parameter, and a misspelt one is refused`() throws {
        let options = try GeneratorOptions(parameter: "visibility=public,unknown_fields=discard")
        #expect(options.visibility == .public)
        #expect(options.discardsUnknownFields)
        #expect(throws: GeneratorError.self) { try GeneratorOptions(parameter: "visibilty=public") }
    }

    @Test func `a field that names a type the set does not hold is an error, not a guess`() throws {
        var broken = try set("oneof")
        broken.files[0].messages[1].fields[0].typeName = ".gen.oneof.Missing"
        broken.files[0].messages[1].fields[0].type = .message
        #expect(throws: GeneratorError.self) { try SwiftGenerator.generate(broken, files: ["oneof.proto"]) }
    }

    @Test func `the plugin answers a request with the files, and an unknown file with an error`() throws {
        let set = try set("packed")
        var request = WireWriter()
        request.appendTag(1, .lengthDelimited)
        request.appendString("packed.proto")
        for file in set.files {
            try request.appendMessage(field: 15) { w throws(WireError) in try file.encode(into: &w) }
        }
        let response = ProtocPlugin.run(request: request.bytes)
        let text = String(decoding: response, as: UTF8.self)
        #expect(text.contains("packed.aemi.swift"))
        #expect(text.contains("@ProtoField(1, packed: false) var numbers: [Int32] = []"))
        var unknown = WireWriter()
        unknown.appendTag(1, .lengthDelimited)
        unknown.appendString("missing.proto")
        #expect(String(decoding: ProtocPlugin.run(request: unknown.bytes), as: UTF8.self).contains("unknownFile"))
    }
}
