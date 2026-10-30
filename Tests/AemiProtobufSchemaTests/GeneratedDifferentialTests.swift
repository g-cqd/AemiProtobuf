import Foundation
import Testing

@testable import AemiProtobufSchema

/// Roadmap 0011: 120 seeded random messages of the proto3 and proto2 test types (Scripts/generated-differential.py), each
/// encoded by protoc. Read as text and written as binary, and read as binary and written again, each gives protoc's bytes.
@Suite struct GeneratedDifferentialTests {
    struct Case: Decodable {
        let seed: Int
        let type: String
        let text: String
        let bytes: String
    }

    @Test func `every generated message gives protoc's bytes, from text and from binary`() throws {
        let url = try #require(
            Bundle.module.url(forResource: "cases", withExtension: "json", subdirectory: "Resources/differential"))
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        #expect(cases.count == 120)
        let schema = DynamicMessageCorpusTests.schema
        let format = ProtoTextFormat(schema: schema)
        for item in cases {
            let expected = DynamicMessageCorpusTests.bytes(item.bytes)
            let fromText = try format.decode(item.text, as: item.type)
            #expect(try schema.encode(fromText) == expected, "seed \(item.seed): \(item.text)")
            #expect(try schema.encode(try schema.decode(expected, as: item.type)) == expected, "seed \(item.seed)")
        }
    }
}
