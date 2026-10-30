import AemiProtobufCore
import Foundation
import Testing

@testable import AemiProtobufSchema

/// Roadmap 0007: the validator against `protoc --decode` on 868 mutations of protoc-written messages (Scripts/validator-corpus.py).
/// What protoc refuses, the validator refuses. Where protoc accepts and the validator does not, the finding is one of the
/// deliberate differences: a declared field with another wire type (C++ keeps it as an unknown field; the validator reports it),
/// a missing required field (`protoc --decode` parses partially; C++'s `ParseFromString` refuses it too), and the varint and tag
/// forms ADR-0003 refuses.
@Suite struct ValidatorDifferentialTests {
    private struct Case {
        let message: String
        let bytes: [UInt8]
        let protocAccepts: Bool
    }

    private func resource(_ name: String, _ ext: String) throws -> URL {
        try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources"))
    }

    private func cases() throws -> [Case] {
        let text = try String(contentsOf: resource("differential", "txt"), encoding: .utf8)
        return text.split(separator: "\n")
            .map { line in
                let parts = line.split(separator: " ")
                let hex = parts[1] == "-" ? "" : String(parts[1])
                var bytes: [UInt8] = []
                var index = hex.startIndex
                while index < hex.endIndex {
                    let next = hex.index(index, offsetBy: 2)
                    bytes.append(UInt8(hex[index ..< next], radix: 16) ?? 0)
                    index = next
                }
                return Case(message: String(parts[0]), bytes: bytes, protocAccepts: parts[2] == "accept")
            }
    }

    private static func isDeliberate(_ error: WireValidationError) -> Bool {
        switch error {
            case .unexpectedWireType, .requiredFieldMissing: true
            case .wireCorrupted(.malformedVarint), .wireCorrupted(.invalidTag): true
            default: false
        }
    }

    @Test func `the validator refuses what protoc refuses, and differs only where it means to`() throws {
        let kinds = try FileDescriptorSet.decode(
            from: [UInt8](try Data(contentsOf: resource("differential-kinds", "pb"))))
        let proto2 = try FileDescriptorSet.decode(
            from: [UInt8](try Data(contentsOf: resource("differential-proto2", "pb"))))
        let all = try cases()
        #expect(all.count == 868)
        var stricter = 0
        for item in all {
            let set = item.message == "Kinds" ? kinds : proto2
            let findings = WireValidator().validate(bytes: item.bytes, against: item.message, in: set)
            let hex = item.bytes.map { String($0, radix: 16) }.joined(separator: " ")
            if !item.protocAccepts {
                #expect(!findings.isEmpty, "protoc refuses \(item.message) [\(hex)], the validator accepts it")
            } else if !findings.isEmpty {
                stricter += 1
                #expect(
                    findings.allSatisfy { Self.isDeliberate($0.error) },
                    "protoc accepts \(item.message) [\(hex)]: \(findings)")
            }
        }
        print(
            "differential: \(all.count) inputs, \(stricter) accepted by protoc and refused by the validator by design")
    }
}
