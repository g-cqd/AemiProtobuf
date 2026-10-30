import AemiProtobufCore
import Testing

@testable import AemiProtobufSchema

/// Roadmap 0006: what protoc's corpus does not reach. Unknown fields, closed enumerations, UTF-8, required fields, wire types,
/// nesting limits, and values that do not fit the descriptor.
@Suite struct DynamicMessageEdgeTests {
    private let schema = DynamicMessageCorpusTests.schema
    private let proto3 = "protobuf_test_messages.proto3.TestAllTypesProto3"
    private let proto2 = "protobuf_test_messages.proto2.TestAllTypesProto2"

    @Test func `an undeclared field is kept and written after the declared ones`() throws {
        // field 1000, varint 5; then optional_int32 = 1
        let input: [UInt8] = [0xC0, 0x3E, 0x05, 0x08, 0x01]
        let message = try schema.decode(input, as: proto3)
        #expect(message.fields == [1: .int32(1)])
        #expect(message.unknownFields.bytes == [0xC0, 0x3E, 0x05])
        #expect(try schema.encode(message) == [0x08, 0x01, 0xC0, 0x3E, 0x05])
    }

    @Test func `a known field with another wire type is kept as unknown`() throws {
        // optional_int32 (1) as fixed32
        let input: [UInt8] = [0x0D, 1, 0, 0, 0]
        let message = try schema.decode(input, as: proto3)
        #expect(message.fields.isEmpty)
        #expect(message.unknownFields.bytes == input)
    }

    @Test func `a closed enumeration's unknown number is an unknown field, an open one's a value`() throws {
        // optional_nested_enum (21) = 7: proto2's enumeration is closed, proto3's open
        let input: [UInt8] = [0xA8, 0x01, 0x07]
        let closed = try schema.decode(input, as: proto2)
        #expect(closed.fields[21] == nil)
        #expect(closed.unknownFields.bytes == input)
        #expect(try schema.decode(input, as: proto3).fields[21] == .enumeration(7))
    }

    @Test func `proto3 refuses a string that is not UTF-8, proto2 keeps its bytes`() throws {
        let input: [UInt8] = [0x72, 0x01, 0xFF]  // optional_string (14)
        #expect(throws: DynamicMessageError.wire(.invalidUTF8(at: 2))) { try schema.decode(input, as: proto3) }
        let kept = try schema.decode(input, as: proto2)
        #expect(kept.fields[14] == .bytes([0xFF]))
        #expect(try schema.encode(kept) == input)
    }

    @Test func `a missing required field is refused, with its path`() throws {
        let type = "protobuf_test_messages.proto2.TestAllRequiredTypesProto2"
        #expect(throws: DynamicMessageError.self) { try schema.decode([], as: type) }
        do {
            _ = try schema.decode([], as: type)
        } catch {
            guard case .wire(.missingRequired(let path)) = error else {
                Issue.record("\(error)")
                return
            }
            #expect(path.hasPrefix(type + "."))
        }
    }

    @Test func `nesting past the limit is refused, and deep nesting needs no recursion`() throws {
        func nested(_ depth: Int) -> [UInt8] {
            var bytes: [UInt8] = []
            for _ in 0 ..< depth {
                var writer = WireWriter()
                writer.appendTag(27, .lengthDelimited)  // recursive_message
                writer.appendBytes(bytes)
                bytes = writer.bytes
            }
            return bytes
        }
        _ = try schema.decode(nested(100), as: proto3)
        #expect(throws: DynamicMessageError.self) { try schema.decode(nested(101), as: proto3) }
        let deep = nested(1_000)
        let limits = WireLimits(maxDepth: 2_000)
        let message = try schema.decode(deep, as: proto3, limits: limits)
        #expect(try schema.encode(message, limits: limits) == deep)
    }

    @Test func `values that do not fit the descriptor are refused`() {
        let wrongType = DynamicMessage(typeName: proto3, fields: [1: .string("x")])
        #expect(throws: DynamicMessageError.typeMismatch(message: proto3, field: "optional_int32")) {
            try schema.encode(wrongType)
        }
        let undeclared = DynamicMessage(typeName: proto3, fields: [5000: .int32(1)])
        #expect(throws: DynamicMessageError.unknownField(message: proto3, number: 5000)) {
            try schema.encode(undeclared)
        }
        #expect(throws: DynamicMessageError.unknownMessageType("no.Such")) { try schema.decode([], as: "no.Such") }
    }
}
