import AemiProtobufCore
import AemiProtobufJSON
import AemiProtobufSchema
import Testing

/// Roadmap 0010: the proto3 JSON mapping (protobuf.dev/programming-guides/json) for scalars, enumerations, repeated fields,
/// maps, oneofs and names.
@Suite struct ProtoJSONMappingTests {
    private typealias S = JSONTestSupport

    @Test func `scalars are written as the mapping says`() throws {
        let message = DynamicMessage(
            typeName: S.proto3,
            fields: [
                1: .int32(5), 2: .int64(-9_000_000_000), 4: .uint64(18_000_000_000_000_000_000), 11: .float(1.5),
                12: .double(.nan), 13: .bool(true), 14: .string("a\"\\\n\u{1}é"), 15: .bytes([0, 255])
            ])
        #expect(
            try S.write(message)
                == #"{"optionalInt32":5,"optionalInt64":"-9000000000","optionalUint64":"18000000000000000000","#
                + #""optionalFloat":1.5,"optionalDouble":"NaN","optionalBool":true,"optionalString":"a\"\\\n\u0001é","#
                + #""optionalBytes":"AP8="}"#)
    }

    @Test func `defaults are left out, presence fields kept, and the empty message is {}`() throws {
        let zeros = DynamicMessage(
            typeName: S.proto3,
            fields: [
                1: .int32(0), 14: .string(""),
                18: .message(.init(typeName: "protobuf_test_messages.proto3.TestAllTypesProto3.NestedMessage"))
            ])
        #expect(try S.write(zeros) == #"{"optionalNestedMessage":{}}"#)
        let emitted = try S.write(DynamicMessage(typeName: S.proto3), options: .init(emitDefaultValues: true))
        #expect(emitted.contains(#""optionalInt32":0"#) && emitted.contains(#""repeatedInt32":[]"#))
        #expect(emitted.contains(#""mapInt32Int32":{}"#) && !emitted.contains("optionalNestedMessage"))
    }

    @Test func `numbers are read from numbers or strings, exactly`() throws {
        let message = try S.read(
            #"{"optionalInt32":"5","optionalInt64":9223372036854775807,"optionalUint32":1e2,"optionalSint64":"-9223372036854775808","#
                + #""optionalFloat":"Infinity","optionalDouble":-1.25e-3,"optional_fixed64":"18446744073709551615"}"#)
        #expect(message.fields[1] == .int32(5))
        #expect(message.fields[2] == .int64(.max))
        #expect(message.fields[3] == .uint32(100))
        #expect(message.fields[6] == .int64(.min))
        #expect(message.fields[11] == .float(.infinity))
        #expect(message.fields[12] == .double(-0.00125))
        #expect(message.fields[8] == .uint64(.max))
        for bad in [
            #"{"optionalInt32":1.5}"#, #"{"optionalInt32":2147483648}"#, #"{"optionalUint32":-1}"#,
            #"{"optionalInt64":"9223372036854775808"}"#, #"{"optionalFloat":3.5e38}"#, #"{"optionalBool":"true"}"#,
            #"{"optionalInt32":" 1"}"#, #"{"optionalDouble":"1e400"}"#
        ] {
            #expect(throws: ProtoJSONError.self, "\(bad)") { try S.read(bad) }
        }
    }

    @Test func `strings and bytes, base64 standard or URL-safe, padded or not`() throws {
        let message = try S.read(#"{"optionalString":"\u00e9\ud83d\ude00","optionalBytes":"-_8"}"#)
        #expect(message.fields[14] == .string("é😀"))
        #expect(message.fields[15] == .bytes([0xFB, 0xFF]))
        #expect(throws: ProtoJSONError.self) { try S.read(#"{"optionalBytes":"!!"}"#) }
        #expect(throws: ProtoJSONError.self) { try S.read(#"{"optionalString":"\ud800"}"#) }
    }

    @Test func `enumerations are names, or numbers when they have none`() throws {
        let message = try S.read(
            #"{"optionalNestedEnum":"BAZ","optionalForeignEnum":1,"repeatedNestedEnum":["FOO",7]}"#)
        #expect(message.fields[21] == .enumeration(2))
        #expect(message.fields[22] == .enumeration(1))
        #expect(message.fields[51] == .list([.enumeration(0), .enumeration(7)]))
        #expect(
            try S.write(message)
                == #"{"optionalNestedEnum":"BAZ","optionalForeignEnum":"FOREIGN_BAR","repeatedNestedEnum":["FOO",7]}"#)
        #expect(throws: ProtoJSONError.self) { try S.read(#"{"optionalNestedEnum":"NOPE"}"#) }
        let ignored = try S.read(
            #"{"optionalNestedEnum":"NOPE","unknownField":[1,{"a":null}]}"#, options: .init(ignoreUnknownFields: true))
        #expect(ignored.fields.isEmpty)
        #expect(throws: ProtoJSONError.self) { try S.read(#"{"unknownField":1}"#) }
    }

    @Test func `field names: lowerCamel out, either form in, proto names on request`() throws {
        let message = try S.read(#"{"optional_int32":1,"fieldName7":2,"FieldName8":3,"field_Name9":4}"#)
        #expect(message.fields[1] == .int32(1) && message.fields[407] == .int32(2))
        #expect(message.fields[408] == .int32(3) && message.fields[409] == .int32(4))
        #expect(try S.write(message, options: .init(useProtoFieldNames: true)).hasPrefix(#"{"optional_int32":1"#))
        #expect(throws: ProtoJSONError.self) { try S.read(#"{"optionalInt32":1,"optional_int32":2}"#) }
    }

    @Test func `repeated fields and maps`() throws {
        let message = try S.roundTrip(
            #"{"repeatedInt64":["1",2],"repeatedNestedMessage":[{"a":1},{}],"mapInt32Int32":{"-1":2},"mapBoolBool":{"true":false},"#
                + #""mapStringNestedMessage":{"k":{"a":3}},"mapInt64Int64":{"9223372036854775807":"1"}}"#)
        #expect(message.fields[32] == .list([.int64(1), .int64(2)]))
        #expect(message.fields[56] == .map([.int32(-1): .int32(2)]))
        #expect(message.fields[68] == .map([.bool(true): .bool(false)]))
        #expect(throws: ProtoJSONError.self) { try S.read(#"{"mapBoolBool":{"yes":true}}"#) }
        #expect(throws: ProtoJSONError.self) { try S.read(#"{"repeatedInt32":[1,null]}"#) }
    }

    @Test func `null is an absent field; a oneof takes one member`() throws {
        let message = try S.read(
            #"{"optionalInt32":null,"repeatedInt32":null,"optionalNestedMessage":null,"oneofUint32":null,"oneofString":"x"}"#
        )
        #expect(message.fields == [113: .string("x")])
        #expect(throws: ProtoJSONError.self) { try S.read(#"{"oneofUint32":1,"oneofString":"x"}"#) }
    }

    @Test func `binary to JSON to binary keeps every case of the dynamic corpus`() throws {
        // Not the well-known case: its `Any` names the type "t", which no JSON writer can resolve.
        for item in try JSONCorpus.cases() where item.name != "proto3-wellknown" {
            let message = try S.schema.decode(JSONCorpus.bytes(item.input), as: item.type)
            let again = try S.read(try S.write(message), as: item.type)
            #expect(try S.schema.encode(again) == JSONCorpus.bytes(item.expected), "\(item.name)")
        }
    }

    @Test func `nesting needs no recursion`() throws {
        let depth = 1_000
        let json =
            String(repeating: #"{"recursiveMessage":"#, count: depth) + "{}" + String(repeating: "}", count: depth)
        let options = ProtoJSONCoder.Options(maxDepth: 2_000)
        let message = try S.read(json, options: options)
        #expect(try S.write(message, options: options) == json)
        #expect(throws: ProtoJSONError.self) { try S.read(json) }  // the default limit is 100
    }
}
