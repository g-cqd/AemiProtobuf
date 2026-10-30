import AemiProtobufCore
import Foundation
import Testing

@testable import AemiProtobufSchema

/// Roadmap 0006: `DynamicMessage` against protoc. Each case is bytes protoc encoded from a text message of a conformance test type
/// (proto3, proto2, and both editions goldens) with `--deterministic_output`; a merge case is several encodings concatenated, and
/// expects protoc's encoding of the merged message (Scripts/dynamic-corpus.py).
@Suite struct DynamicMessageCorpusTests {
    struct Case: Decodable {
        let name: String
        let type: String
        let input: String
        let expected: String
    }

    static let schema: DynamicSchema = {
        guard
            let url = Bundle.module.url(forResource: "conformance-set", withExtension: "pb", subdirectory: "Resources"),
            let data = try? Data(contentsOf: url), let set = try? FileDescriptorSet.decode(from: [UInt8](data))
        else { return DynamicSchema(FileDescriptorSet(files: [])) }
        return DynamicSchema(set)
    }()

    static func cases() throws -> [Case] {
        let url = try #require(
            Bundle.module.url(forResource: "cases", withExtension: "json", subdirectory: "Resources/dynamic"))
        return try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
    }

    static func bytes(_ hex: String) -> [UInt8] {
        var result: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            result.append(UInt8(hex[index ..< next], radix: 16) ?? 0)
            index = next
        }
        return result
    }

    @Test func `every case decodes and encodes again to protoc's bytes`() throws {
        let cases = try Self.cases()
        #expect(cases.count == 32)
        for item in cases {
            let message = try Self.schema.decode(Self.bytes(item.input), as: item.type)
            #expect(try Self.schema.encode(message) == Self.bytes(item.expected), "\(item.name)")
        }
    }

    @Test func `values have the field's Swift type`() throws {
        let item = try #require(try Self.cases().first { $0.name == "proto3-scalars" })
        let message = try Self.schema.decode(Self.bytes(item.input), as: item.type)
        #expect(message.fields[1] == .int32(-5))
        #expect(message.fields[2] == .int64(-9_000_000_000))
        #expect(message.fields[3] == .uint32(4_000_000_000))
        #expect(message.fields[5] == .int32(-77))
        #expect(message.fields[12] == .double(-2.25))
        #expect(message.fields[14] == .string("héllo"))
        #expect(message.fields[15] == .bytes([0, 255]))
        #expect(message.fields[21] == .enumeration(2))
        #expect(message.fields[1001] == nil)
        let maps = try #require(try Self.cases().first { $0.name == "proto3-maps" })
        let decoded = try Self.schema.decode(Self.bytes(maps.input), as: maps.type)
        #expect(decoded.fields[56] == .map([.int32(1): .int32(10), .int32(2): .int32(20)]))
        let nested = try #require(decoded.fields[71])
        guard case .map(let entries) = nested, case .message(let value)? = entries[.string("m")] else {
            Issue.record("map_string_nested_message is \(nested)")
            return
        }
        #expect(value.fields[1] == .int32(9))
    }
}
