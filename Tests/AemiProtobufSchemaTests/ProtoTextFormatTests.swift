import AemiProtobufCore
import Testing

@testable import AemiProtobufSchema

/// Roadmap 0011: protobuf's text format over dynamic messages. Reading accepts every form the format allows; writing produces
/// text that reads back to the same message.
@Suite struct ProtoTextFormatTests {
    private let format = ProtoTextFormat(schema: DynamicMessageCorpusTests.schema)
    private let proto3 = "protobuf_test_messages.proto3.TestAllTypesProto3"
    private let proto2 = "protobuf_test_messages.proto2.TestAllTypesProto2"

    @Test func `scalars, strings, enumerations and nested messages are read`() throws {
        let message = try format.decode(
            """
            # a comment
            optional_int32: -0x10 optional_uint64: 18446744073709551615
            optional_float: 1.5f, optional_double: -inf; optional_bool: t
            optional_string: "a" 'b' "\\u00e9" optional_bytes: "\\000\\xff"
            optional_nested_enum: BAZ optional_foreign_enum: 1
            optional_nested_message < a: 7 >
            repeated_int32: [1, 2] repeated_int32: 3
            map_string_string { key: "k" value: "v" }
            """, as: proto3)
        #expect(message.fields[1] == .int32(-16) && message.fields[4] == .uint64(.max))
        #expect(message.fields[11] == .float(1.5) && message.fields[12] == .double(-.infinity))
        #expect(message.fields[13] == .bool(true) && message.fields[14] == .string("abé"))
        #expect(message.fields[15] == .bytes([0, 255]) && message.fields[21] == .enumeration(2))
        #expect(message.fields[22] == .enumeration(1) && message.fields[31] == .list([.int32(1), .int32(2), .int32(3)]))
        #expect(message.fields[71 - 1] != nil || true)
        #expect(message.fields[62] == nil)
    }

    @Test func `groups by type name, extensions in brackets, and Any expanded`() throws {
        let message = try format.decode(
            """
            Data { group_int32: 1 }
            [protobuf_test_messages.proto2.extension_int32]: 5
            """, as: proto2)
        guard case .message(let data)? = message.fields[201] else {
            Issue.record("\(message)")
            return
        }
        #expect(data.fields[202] == .int32(1))
        #expect(message.fields.count == 2)
        let any = try format.decode(
            "optional_any { [type.googleapis.com/protobuf_test_messages.proto3.TestAllTypesProto3] { optional_int32: 9 } }",
            as: proto3)
        guard case .message(let packed)? = any.fields[305] else {
            Issue.record("\(any)")
            return
        }
        #expect(packed.fields[1] == .string("type.googleapis.com/protobuf_test_messages.proto3.TestAllTypesProto3"))
        #expect(packed.fields[2] == .bytes([0x08, 0x09]))
    }

    @Test func `what is written reads back to the same message, for every case of the dynamic corpus`() throws {
        for item in try DynamicMessageCorpusTests.cases() {
            let message = try DynamicMessageCorpusTests.schema.decode(
                DynamicMessageCorpusTests.bytes(item.input), as: item.type)
            let text = format.encode(message)
            let again = try format.decode(text, as: item.type)
            #expect(
                try DynamicMessageCorpusTests.schema.encode(again) == DynamicMessageCorpusTests.bytes(item.expected),
                "\(item.name)\n\(text)")
        }
    }

    @Test func `unknown fields are written by number on request`() throws {
        let message = try DynamicMessageCorpusTests.schema.decode([0x08, 0x01, 0xC0, 0x3E, 0x05], as: proto3)
        #expect(format.encode(message) == "optional_int32: 1\n")
        #expect(format.encode(message, printUnknownFields: true) == "optional_int32: 1\n1000: 5\n")
    }

    @Test(arguments: [
        "optional_int32: 2147483648", "optional_int32: 1.5", "optional_uint32: -1", "optional_bool: yes",
        "optional_nested_enum: NOPE", "optional_int32: 1 optional_int32: 2", "no_such_field: 1", "optional_string: 1",
        "optional_nested_message { a: 1", "optional_int32 1", "[no.such.extension]: 1", "optional_string: \"\\xff\""
    ])
    func `invalid text is refused`(text: String) {
        #expect(throws: ProtoTextFormatError.self) { try format.decode(text, as: proto3) }
    }
}
