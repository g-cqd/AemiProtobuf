import Foundation
import Testing

/// The dynamic message corpus (Scripts/dynamic-corpus.py), copied here: protoc's bytes for messages of the conformance types.
enum JSONCorpus {
    struct Case: Decodable {
        let name: String
        let type: String
        let input: String
        let expected: String
    }

    static func cases() throws -> [Case] {
        let url = try #require(
            Bundle.module.url(forResource: "dynamic-cases", withExtension: "json", subdirectory: "Resources"))
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
}
