import AemiJSON
import AemiProtobuf
import AemiProtobufCore
import Foundation
import SwiftProtobuf

/// The outcome of checking every codec round-trips the corpus. A false entry is reported, never hidden.
public struct Verification: Sendable {
    public var findings: [String] = []
    public var codableProtobufWorks = false

    public var passed: Bool { findings.isEmpty }
}

extension Codecs {
    /// Round-trips the corpus through every codec and checks the formats agree with each other.
    public func verify() -> Verification {
        var v = Verification()
        func check(_ ok: Bool, _ what: String) { if !ok { v.findings.append(what) } }
        func run<T>(_ what: String, _ body: () throws -> T) -> T? {
            do { return try body() } catch {
                v.findings.append("\(what) threw \(error)")
                return nil
            }
        }
        let aemiDecoder = AemiJSON.JSONDecoder()
        check(
            run("aemi json decode") { try aemiDecoder.decode([JSONUser].self, from: jsonAemi).map(\.record) }
                == records,
            "AemiJSON Codable round trip")
        check(
            run("macro decode") { try aemiDecoder.decode([MacroJSONUser].self, from: jsonAemi).map(\.record) }
                == records,
            "AemiJSON @JSONCodable decodes AemiJSON bytes")
        check(
            run("foundation decodes aemi") {
                try Foundation.JSONDecoder().decode([JSONUser].self, from: jsonAemi).map(\.record)
            } == records, "Foundation decodes AemiJSON bytes")
        check(
            run("aemi decodes foundation") {
                try aemiDecoder.decode([JSONUser].self, from: jsonFoundation).map(\.record)
            }
                == records, "AemiJSON decodes Foundation bytes")
        check(
            run("proto fast decode") { try ProtobufDecoder().decode(ProtoUsers.self, fromBytes: protoFast).records }
                == records, "AemiProtobuf fast-path round trip")
        var direct = WireWriter(reservingCapacity: 128)
        do throws(WireError) { try protoUsers.__aepbEncode(into: &direct) } catch {
            v.findings.append("direct writer threw \(error)")
        }
        check(direct.bytes == protoFast, "direct writer bytes equal ProtobufEncoder bytes")
        if let codable = protoCodable {
            let decoded = run("codable decode of fast bytes") {
                try ProtobufDecoder().decode(CodableProtoUsers.self, fromBytes: protoFast)
            }
            let same = codable == protoFast && decoded == codableProtoUsers
            v.codableProtobufWorks = same
            if !same {
                v.findings.append(
                    "AemiProtobuf generic Codable path does not round-trip this corpus (bytes equal: \(codable == protoFast), decode equal: \(decoded == codableProtoUsers))"
                )
            }
        } else {
            v.findings.append("AemiProtobuf generic Codable path cannot encode this corpus")
        }
        // The two protobuf implementations must agree byte for byte, and each must read the other's bytes.
        check(swiftProtobufBytes == protoFast, "swift-protobuf and AemiProtobuf write different bytes")
        check(
            run("swift-protobuf decodes aemi bytes") {
                SwiftProtobufUsers.records(try Users(serializedBytes: protoFast))
            }
                == records, "swift-protobuf decodes AemiProtobuf bytes")
        check(
            run("aemi decodes swift-protobuf bytes") {
                try ProtobufDecoder().decode(ProtoUsers.self, fromBytes: swiftProtobufBytes).records
            } == records, "AemiProtobuf decodes swift-protobuf bytes")
        return v
    }
}
