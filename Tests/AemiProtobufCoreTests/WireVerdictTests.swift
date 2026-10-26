import Foundation
import Testing

@testable import AemiProtobufCore

/// Differential test against `protoc --decode_raw` (Scripts/golden/decode-raw-verdicts.py): 1,500 seeded, mutated buffers
/// and whether protoc accepted each. The expected verdict comes from protoc.
struct WireVerdictTests {
    struct Case: Decodable {
        let hex: String
        let protoc: Bool
    }

    /// The verdict of walking every top-level field, the part of `--decode_raw` that does not guess at nested messages.
    static func verdict(_ bytes: [UInt8]) -> WireError? {
        do throws(WireError) {
            try read(bytes) { r throws(WireError) in
                while let next = try r.nextTag() { try r.skipField(next) }
            }
            return nil
        } catch {
            return error
        }
    }

    static func loadCases() throws -> [Case] {
        let url = try #require(
            Bundle.module.url(forResource: "decode-raw-verdicts", withExtension: "jsonl", subdirectory: "Resources"))
        return try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
            .map {
                try JSONDecoder().decode(Case.self, from: Data($0.utf8))
            }
    }

    @Test func `the reader accepts what protoc accepts and refuses what protoc refuses`() throws {
        let cases = try Self.loadCases()
        #expect(cases.count == 1500)
        var unexplained: [String] = []
        var strictRefusals = 0
        for c in cases {
            let error = Self.verdict(hex(c.hex))
            guard (error == nil) != c.protoc else { continue }
            // The deliberate differences (ADR-0003): protoc truncates a varint whose tenth byte is above 1, and truncates a
            // tag above 32 bits. We refuse both. protoc refusing what we accept would be a bug here, and is never excused.
            switch error {
                case .malformedVarint?: strictRefusals += 1
                case .invalidTag(let raw, _)? where raw > UInt64(UInt32.max): strictRefusals += 1
                default: unexplained.append("\(c.hex) protoc=\(c.protoc) ours=\(String(describing: error))")
            }
        }
        #expect(unexplained == [], "disagreements other than the two documented strict refusals")
        #expect(strictRefusals > 0, "the corpus must exercise the documented difference, or this allowance is dead")
    }

    @Test func `random buffers never trap and always end in a value or a wire error`() {
        var rng = SplitMix64(state: 0x5EED)
        for _ in 0 ..< 5_000 {
            let length = Int(rng.next() % 64)
            let bytes = (0 ..< length).map { _ in UInt8(truncatingIfNeeded: rng.next()) }
            _ = Self.verdict(bytes)
        }
    }
}
