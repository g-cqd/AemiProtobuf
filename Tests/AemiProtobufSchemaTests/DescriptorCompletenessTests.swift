import AemiProtobufCore
import Foundation
import Testing

@testable import AemiProtobufSchema

/// Roadmap 0002 and 0028: the descriptor model holds everything protoc writes for the conformance messages, `descriptor.proto`
/// and the well-known types, and writes it back byte for byte.
@Suite struct DescriptorCompletenessTests {
    private func set() throws -> (FileDescriptorSet, [UInt8]) {
        let url = try #require(
            Bundle.module.url(forResource: "conformance-set", withExtension: "pb", subdirectory: "Resources"))
        let bytes = [UInt8](try Data(contentsOf: url))
        return (try FileDescriptorSet.decode(from: bytes), bytes)
    }

    private func message(_ name: String, in set: FileDescriptorSet) -> MessageDescriptor? {
        set.files.lazy.flatMap(\.messages).first { $0.name == name }
    }

    @Test func `protoc's descriptor set re-encodes byte for byte`() throws {
        let (decoded, bytes) = try set()
        #expect(decoded.files.count == 14)
        #expect(try decoded.encode() == bytes)
    }

    @Test func `files keep their dependencies, extensions, syntax and edition`() throws {
        let (decoded, _) = try set()
        let proto2 = try #require(decoded.files.first { $0.name == "google/protobuf/test_messages_proto2.proto" })
        #expect(proto2.syntax == "proto2")
        #expect(proto2.extensions.map(\.name).contains("extension_int32"))
        #expect(proto2.extensions.first?.extendee == ".protobuf_test_messages.proto2.TestAllTypesProto2")
        let proto3 = try #require(decoded.files.first { $0.name == "google/protobuf/test_messages_proto3.proto" })
        #expect(proto3.dependencies.contains("google/protobuf/any.proto"))
        let edition = try #require(decoded.files.first { $0.name.hasSuffix("test_messages_edition2023.proto") })
        #expect(edition.syntax == "editions")
        #expect(edition.edition == 1000)
    }

    @Test func `messages keep options, extension ranges and reserved ranges, and the options read back`() throws {
        let (decoded, _) = try set()
        let all = try #require(message("TestAllTypesProto2", in: decoded))
        #expect(all.extensionRanges.contains { $0.start == 120 && $0.end == 201 })
        let set = try #require(all.nestedMessages.first { $0.name == "MessageSetCorrect" })
        #expect(set.messageSetWireFormat)
        let mapEntry = try #require(all.nestedMessages.first { $0.name == "MapInt32Int32Entry" })
        #expect(mapEntry.isMapEntry)
        let proto3 = try #require(message("TestAllTypesProto3", in: decoded))
        #expect(!proto3.reservedRanges.isEmpty || !proto3.reservedNames.isEmpty)
    }

    @Test func `fields keep default values and options, and packed reads back`() throws {
        let (decoded, _) = try set()
        let all = try #require(message("TestAllTypesProto2", in: decoded))
        let defaultInt32 = try #require(all.fields.first { $0.name == "default_int32" })
        #expect(defaultInt32.defaultValue == "-123456789")
        let packed = try #require(all.fields.first { $0.name == "packed_int32" })
        #expect(packed.packed == true)
        let unpacked = try #require(all.fields.first { $0.name == "unpacked_int32" })
        #expect(unpacked.packed == false)
    }

    @Test func `enums keep aliases, and edition features read back`() throws {
        let (decoded, _) = try set()
        let proto3 = try #require(message("TestAllTypesProto3", in: decoded))
        let aliased = try #require(proto3.nestedEnums.first { $0.name == "AliasedEnum" })
        #expect(aliased.allowAlias)
        let edition = try #require(decoded.files.first { $0.name.hasSuffix("test_messages_edition2023.proto") })
        // `option features.message_encoding = DELIMITED;` at file level (DELIMITED is 2).
        #expect(edition.features?.messageEncoding == 2)
        let all = try #require(edition.messages.first { $0.name == "TestAllTypesEdition2023" })
        let packed = try #require(all.fields.first { $0.name == "packed_int32" })
        #expect(packed.features?.repeatedFieldEncoding == 1)
    }

    @Test func `a field the model does not know is kept and written back`() throws {
        // A FileDescriptorProto with name "a" and an unknown field 99.
        let file: [UInt8] = [0x0A, 0x01, 0x61, 0x98, 0x06, 0x01]
        let bytes: [UInt8] = [0x0A, UInt8(file.count)] + file
        let decoded = try FileDescriptorSet.decode(from: bytes)
        #expect(try decoded.encode() == bytes)
    }
}
