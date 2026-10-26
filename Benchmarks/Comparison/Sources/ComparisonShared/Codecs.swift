import AemiJSON
import AemiProtobuf
public import Foundation
import SwiftProtobuf

/// Every encoder and decoder under comparison, behind one set of closures over `Record` lists, so the benchmarks and the
/// verification run exactly the same code. A closure that fails throws; no benchmark swallows an error.
public struct Codecs {
    public let n: Int
    public let records: [Record]
    // Payloads, each produced once by its own encoder.
    public let jsonAemi: Data
    public let jsonFoundation: Data
    public let protoFast: [UInt8]
    public let protoCodable: [UInt8]?
    /// swift-protobuf's generated messages and its own encoding of them.
    public let swiftProtobufUsers: Users
    public let swiftProtobufBytes: [UInt8]

    public let jsonUsers: [JSONUser]
    public let macroUsers: [MacroJSONUser]
    public let protoUsers: ProtoUsers
    public let codableProtoUsers: CodableProtoUsers

    public init(count: Int) throws {
        n = count
        records = Corpus.records(count)
        jsonUsers = records.map(JSONUser.init)
        macroUsers = records.map(MacroJSONUser.init)
        protoUsers = ProtoUsers(records)
        codableProtoUsers = CodableProtoUsers(records)
        jsonAemi = try AemiJSON.JSONEncoder().encode(jsonUsers)
        jsonFoundation = try Foundation.JSONEncoder().encode(jsonUsers)
        protoFast = try ProtobufEncoder().encodeToBytes(protoUsers)
        protoCodable = try? ProtobufEncoder().encodeToBytes(codableProtoUsers)
        swiftProtobufUsers = SwiftProtobufUsers.make(records)
        swiftProtobufBytes = try swiftProtobufUsers.serializedBytes()
    }
}
