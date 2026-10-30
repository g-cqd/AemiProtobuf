import AemiProtobufCore
import AemiProtobufJSON
import AemiProtobufSchema
import Testing

/// Roadmap 0010: the well-known types' JSON forms: Timestamp, Duration, FieldMask, the wrappers, Struct / Value / ListValue,
/// Empty and Any.
@Suite struct ProtoJSONWellKnownTests {
    private typealias S = JSONTestSupport

    private func field(_ json: String, _ number: Int32) throws -> DynamicMessage? {
        guard case .message(let value)? = try S.read(json).fields[number] else { return nil }
        return value
    }

    @Test func `Timestamp is RFC 3339 in UTC, with 0, 3, 6 or 9 fractional digits`() throws {
        let epoch = try #require(try field(#"{"optionalTimestamp":"1970-01-01T00:00:00Z"}"#, 101))
        #expect(epoch.fields.isEmpty)
        let offset = try #require(try field(#"{"optionalTimestamp":"1970-01-01T01:00:01.5+01:00"}"#, 101))
        #expect(offset.fields == [1: .int64(1), 2: .int32(500_000_000)])
        let max = try #require(try field(#"{"optionalTimestamp":"9999-12-31T23:59:59.999999999Z"}"#, 101))
        #expect(max.fields[1] == .int64(253_402_300_799))
        #expect(
            try S.write(try S.read(#"{"optionalTimestamp":"2017-01-15T01:30:15.010Z"}"#))
                == #"{"optionalTimestamp":"2017-01-15T01:30:15.010Z"}"#)
        #expect(
            try S.write(try S.read(#"{"optionalTimestamp":"1969-12-31T23:59:59.000001Z"}"#))
                == #"{"optionalTimestamp":"1969-12-31T23:59:59.000001Z"}"#)
        for bad in [
            "0000-01-01T00:00:00Z", "1970-01-01T00:00:00", "1970-01-01 00:00:00Z", "1970-01-01T00:00:00.1234567890Z",
            "1970-01-01t00:00:00z"
        ] {
            #expect(throws: ProtoJSONError.self, "\(bad)") { try S.read(#"{"optionalTimestamp":""# + bad + #""}"#) }
        }
    }

    @Test func `Duration is seconds with an s, signed, 0, 3, 6 or 9 fractional digits`() throws {
        let value = try #require(try field(#"{"optionalDuration":"-1.5s"}"#, 102))
        #expect(value.fields == [1: .int64(-1), 2: .int32(-500_000_000)])
        #expect(
            try S.write(try S.read(#"{"optionalDuration":"-0.000000001s"}"#))
                == #"{"optionalDuration":"-0.000000001s"}"#)
        #expect(try S.write(try S.read(#"{"optionalDuration":"3s"}"#)) == #"{"optionalDuration":"3s"}"#)
        #expect(try S.write(try S.read(#"{"optionalDuration":"1.25s"}"#)) == #"{"optionalDuration":"1.250s"}"#)
        for bad in ["1", "1.5", "315576000001s", "1.0000000001s", "- 1s", "s"] {
            #expect(throws: ProtoJSONError.self, "\(bad)") { try S.read(#"{"optionalDuration":""# + bad + #""}"#) }
        }
    }

    @Test func `FieldMask is comma-separated lowerCamel paths`() throws {
        let mask = try #require(try field(#"{"optionalFieldMask":"fooBar,baz.quxQuux"}"#, 104))
        #expect(mask.fields == [1: .list([.string("foo_bar"), .string("baz.qux_quux")])])
        #expect(
            try S.write(try S.read(#"{"optionalFieldMask":"fooBar,baz"}"#)) == #"{"optionalFieldMask":"fooBar,baz"}"#)
        #expect(throws: ProtoJSONError.self) { try S.read(#"{"optionalFieldMask":"foo_bar"}"#) }
    }

    @Test func `wrappers are their value, and null is absent`() throws {
        let message = try S.read(
            #"{"optionalInt32Wrapper":0,"optionalInt64Wrapper":"5","optionalStringWrapper":"","optionalBoolWrapper":null}"#
        )
        guard case .message(let int32)? = message.fields[201], case .message(let int64)? = message.fields[202] else {
            Issue.record("\(message)")
            return
        }
        #expect(int32.fields.isEmpty)
        #expect(int64.fields == [1: .int64(5)])
        #expect(message.fields[208] == nil)
        #expect(
            try S.write(message) == #"{"optionalInt32Wrapper":0,"optionalInt64Wrapper":"5","optionalStringWrapper":""}"#
        )
    }

    @Test func `Struct, Value and ListValue are any JSON`() throws {
        let json =
            #"{"optionalStruct":{"a":[1,"x",null,{"b":true}],"c":{}},"optionalValue":null,"repeatedValue":[[],"s"]}"#
        let message = try S.roundTrip(json)
        #expect(message.fields[306] != nil)  // optionalValue: null is a Value holding null_value, not an absent field
        #expect(try S.write(message) == json)
    }

    @Test func `Empty is {} and Any carries its type URL`() throws {
        let any =
            #"{"optionalAny":{"@type":"type.googleapis.com/protobuf_test_messages.proto3.TestAllTypesProto3","optionalInt32":1}}"#
        #expect(try S.write(try S.roundTrip(any)) == any)
        let wellKnown = #"{"optionalAny":{"@type":"type.googleapis.com/google.protobuf.Duration","value":"1s"}}"#
        #expect(try S.write(try S.roundTrip(wellKnown)) == wellKnown)
        let late =
            #"{"optionalAny":{"optionalInt32":1,"@type":"type.googleapis.com/protobuf_test_messages.proto3.TestAllTypesProto3"}}"#
        #expect(try S.write(try S.read(late)) == any)
        #expect(throws: ProtoJSONError.self) { try S.read(#"{"optionalAny":{"optionalInt32":1}}"#) }
        #expect(throws: ProtoJSONError.self) { try S.read(#"{"optionalAny":{"@type":"type.googleapis.com/no.Such"}}"#) }
        #expect(try S.write(try S.read(#"{"optionalAny":{}}"#)) == #"{"optionalAny":{}}"#)
    }
}
