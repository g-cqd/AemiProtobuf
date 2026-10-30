import AemiProtobufCore
import AemiProtobufJSON
import AemiProtobufSchema
import Foundation
import Testing

/// The conformance descriptor set, the coder over it, and helpers shared by the JSON tests.
enum JSONTestSupport {
    static let proto3 = "protobuf_test_messages.proto3.TestAllTypesProto3"
    static let proto2 = "protobuf_test_messages.proto2.TestAllTypesProto2"

    static let schema: DynamicSchema = {
        guard
            let url = Bundle.module.url(forResource: "conformance-set", withExtension: "pb", subdirectory: "Resources"),
            let data = try? Data(contentsOf: url), let set = try? FileDescriptorSet.decode(from: [UInt8](data))
        else { return DynamicSchema(FileDescriptorSet(files: [])) }
        return DynamicSchema(set)
    }()

    static let coder = ProtoJSONCoder(schema: schema)

    /// Reads `json` as a `TestAllTypesProto3` (or `type`).
    static func read(_ json: String, as type: String = proto3, options: ProtoJSONCoder.Options = .init())
        throws(ProtoJSONError) -> DynamicMessage
    {
        try ProtoJSONCoder(schema: schema, options: options).decode(json: Array(json.utf8), as: type)
    }

    /// Writes `message` as JSON text.
    static func write(_ message: DynamicMessage, options: ProtoJSONCoder.Options = .init()) throws(ProtoJSONError)
        -> String
    {
        String(decoding: try ProtoJSONCoder(schema: schema, options: options).encode(message), as: UTF8.self)
    }

    /// Reads `json`, writes it, reads that again: the two messages are equal.
    static func roundTrip(_ json: String, as type: String = proto3) throws -> DynamicMessage {
        let first = try read(json, as: type)
        let second = try read(try write(first), as: type)
        #expect(first == second, "\(json)")
        return first
    }
}
