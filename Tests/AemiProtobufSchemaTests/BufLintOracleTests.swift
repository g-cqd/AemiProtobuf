import Foundation
import Testing

@testable import AemiProtobufSchema

/// Roadmap 0008: the linter against `buf lint` (1.75) with buf's BASIC naming and enumeration rules, on a file with each kind of
/// violation and the names buf accepts that a stricter reading would not (`HTTPServer`, `field1`, `good_field_2`).
@Suite struct BufLintOracleTests {
    private func resource(_ name: String, _ ext: String) throws -> URL {
        try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources/lint"))
    }

    @Test func `the linter reports what buf reports, rule and name`() throws {
        let set = try FileDescriptorSet.decode(from: [UInt8](try Data(contentsOf: resource("lint", "pb"))))
        let oracle = try JSONDecoder()
            .decode([[String]].self, from: Data(contentsOf: resource("lint-expected", "json")))
        let found = SchemaLinter().lint(set).map { [$0.rule, $0.name] }
        #expect(found.sorted { $0.lexicographicallyPrecedes($1) } == oracle.sorted { $0.lexicographicallyPrecedes($1) })
    }

    @Test func `a reserved range that holds a field is a finding (protoc refuses it too)`() {
        let message = MessageDescriptor(
            name: "M", fields: [FieldDescriptor(name: "a", number: 3)])
        var withReserved = message
        withReserved.reservedRanges = [DescriptorRange(start: 1, end: 5)]
        let set = FileDescriptorSet(files: [FileDescriptor(name: "m.proto", package: "p", messages: [withReserved])])
        #expect(SchemaLinter().lint(set).map(\.rule) == ["RESERVED_RANGE_HOLDS_FIELD"])
    }
}
