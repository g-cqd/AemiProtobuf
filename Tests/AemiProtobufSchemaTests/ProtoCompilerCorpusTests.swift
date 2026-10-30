import AemiProtobufCore
import Foundation
import Testing

@testable import AemiProtobufSchema

/// Roadmap 0002: the `.proto` compiler against protoc. Each root (the well-known types, `descriptor.proto`, the conformance
/// and editions test messages, and fixtures for maps, groups, options, extensions, reserved names, defaults, services and
/// editions features) compiles, imports included, to exactly the descriptor set protoc wrote (Scripts/parser-corpus.py).
@Suite struct ProtoCompilerCorpusTests {
    static let roots = [
        "google/protobuf/any.proto", "google/protobuf/api.proto", "google/protobuf/duration.proto",
        "google/protobuf/empty.proto", "google/protobuf/field_mask.proto", "google/protobuf/source_context.proto",
        "google/protobuf/struct.proto", "google/protobuf/timestamp.proto", "google/protobuf/type.proto",
        "google/protobuf/wrappers.proto", "google/protobuf/descriptor.proto",
        "google/protobuf/test_messages_proto3.proto",
        "google/protobuf/test_messages_proto2.proto", "editions/golden/test_messages_proto2_editions.proto",
        "editions/golden/test_messages_proto3_editions.proto",
        "conformance/test_protos/test_messages_edition2023.proto",
        "conformance/conformance.proto", "fixtures/kitchen.proto", "fixtures/modern.proto", "fixtures/edition.proto"
    ]

    static func source(_ path: String) -> String? {
        guard let base = Bundle.module.resourceURL?.appending(path: "Resources/parser/src") else { return nil }
        return try? String(contentsOf: base.appending(path: path), encoding: .utf8)
    }

    static let compiler = ProtoCompiler { source($0) }

    static func expected(_ root: String) throws -> FileDescriptorSet {
        let name = String(root.replacingOccurrences(of: "/", with: "_").dropLast(".proto".count))
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "pb", subdirectory: "Resources/parser/expected"))
        return try FileDescriptorSet.decode(from: [UInt8](Data(contentsOf: url)))
    }

    @Test(arguments: roots) func `compiles as protoc does`(root: String) throws {
        let expected = try Self.expected(root)
        let compiled = try Self.compiler.compile([root])
        #expect(compiled.files.map(\.name) == expected.files.map(\.name))
        for (ours, theirs) in zip(compiled.files, expected.files) where ours != theirs {
            Issue.record("\(ours.name) differs: \(DescriptorDifference.first(ours, theirs))")
        }
        #expect(try compiled.encode() == expected.encode())
    }

    @Test(arguments: roots) func `printed files compile to the same descriptors`(root: String) throws {
        let expected = try Self.expected(root)
        var sources: [String: String] = [:]
        for file in expected.files { sources[file.name] = ProtoPrinter().print(file) }
        let printed = sources
        let recompiled = try ProtoCompiler { printed[$0] }.compile([root])
        for (ours, theirs) in zip(recompiled.files, expected.files) where ours != theirs {
            Issue.record("\(ours.name) differs after printing: \(DescriptorDifference.first(ours, theirs))")
        }
    }
}
