import Foundation
import Testing

@testable import AemiProtobufSchema

/// Roadmap 0008: the comparator against `buf breaking` (1.75, WIRE rules) on fourteen schema changes, one per kind
/// (Scripts/breaking-corpus.py; buf's verdicts in `breaking/expected.json`). For each pair, the wire-breaking changes the
/// comparator reports name exactly the rules buf reports.
@Suite struct BufBreakingOracleTests {
    private static let directory = "Resources/breaking"

    private func load(_ name: String) throws -> FileDescriptorSet {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "pb", subdirectory: Self.directory))
        return try FileDescriptorSet.decode(from: [UInt8](try Data(contentsOf: url)))
    }

    private static func oracle() throws -> [String: [String]] {
        let url = try #require(
            Bundle.module.url(forResource: "expected", withExtension: "json", subdirectory: directory))
        return try JSONDecoder().decode([String: [String]].self, from: try Data(contentsOf: url))
    }

    @Test func `every pair reports the rules buf reports`() throws {
        let expected = try Self.oracle()
        #expect(expected.count == 14)
        for (name, rules) in expected.sorted(by: { $0.key < $1.key }) {
            let changes = SchemaComparator().compare(old: try load("\(name)-old"), new: try load("\(name)-new"))
            let reported = Set(changes.filter(\.breaksTheWire).map(\.bufRule))
            #expect(reported == Set(rules), "\(name): \(changes)")
        }
    }

    @Test func `the changes buf files under other categories are reported, as not breaking the wire`() throws {
        let removed = SchemaComparator()
            .compare(old: try load("remove-message-old"), new: try load("remove-message-new"))
        #expect(removed.map(\.bufRule) == ["MESSAGE_NO_DELETE"])
        let json = SchemaComparator().compare(old: try load("json-name-old"), new: try load("json-name-new"))
        #expect(json.map(\.bufRule) == ["FIELD_SAME_JSON_NAME"])
        #expect(json.allSatisfy { !$0.breaksTheWire })
    }
}
