import AemiProtobufCore
import Foundation
import Testing

@testable import AemiProtobufSchema

/// Roadmap 0007: groups are checked as the messages they hold, declared extensions as fields, and in strict mode a closed
/// enumeration's number with no value is a finding, as is a field outside both the message and its extension ranges.
@Suite struct Proto2ValidationTests {
    private func set() throws -> FileDescriptorSet {
        let url = try #require(
            Bundle.module.url(forResource: "proto2-validation", withExtension: "pb", subdirectory: "Resources"))
        return try FileDescriptorSet.decode(from: [UInt8](try Data(contentsOf: url)))
    }

    private func findings(_ bytes: [UInt8], strict: Bool = false) throws -> [WireFinding] {
        try WireValidator(allowUnknownFields: !strict).validate(bytes: bytes, against: "val.Holder", in: set())
    }

    @Test func `a group's fields are checked as a nested message's`() throws {
        #expect(try findings([0x13, 0x1A, 0x01, 0x78, 0x14]).isEmpty)
        let wrong = try findings([0x13, 0x18, 0x01, 0x14])
        #expect(wrong.map(\.path) == ["g"])
        #expect(wrong.first?.error == .unexpectedWireType(field: 3, expected: .lengthDelimited, actual: .varint, at: 2))
    }

    @Test func `a declared extension is checked as a field, and an undeclared one in range is not unknown`() throws {
        #expect(try findings([0xA2, 0x06, 0x01, 0x78], strict: true).isEmpty)
        let wrong = try findings([0xA0, 0x06, 0x01])
        #expect(
            wrong.map(\.error) == [.unexpectedWireType(field: 100, expected: .lengthDelimited, actual: .varint, at: 2)])
        #expect(try findings([0xB0, 0x09, 0x01], strict: true).isEmpty)
        #expect(try findings([0xE0, 0x12, 0x01], strict: true).map(\.error) == [.unknownField(300, at: 2)])
    }

    @Test func `a closed enumeration's number with no value is a finding when strict, singular and packed`() throws {
        #expect(try findings([0x20, 0x07]).isEmpty)
        #expect(try findings([0x20, 0x07], strict: true).map(\.error) == [.unknownEnumValue(field: 4, value: 7, at: 1)])
        #expect(
            try findings([0x2A, 0x02, 0x01, 0x07], strict: true).map(\.error) == [
                .unknownEnumValue(field: 5, value: 7, at: 3)
            ])
        #expect(try findings([0x20, 0x01, 0x2A, 0x01, 0x00], strict: true).isEmpty)
    }
}
