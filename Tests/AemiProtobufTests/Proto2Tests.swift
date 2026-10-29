import AemiProtobuf
import AemiProtobufCore
import Testing

/// Roadmap 0027: groups and required fields, against protoc's proto2 encodings.
@Suite struct Proto2Tests {
    private func decode<T: AemiProtoFastDecodable & Decodable>(_ type: T.Type, _ bytes: [UInt8]) throws -> T {
        try ProtobufDecoder().decode(type, fromBytes: bytes)
    }

    private func missing(_ body: () throws -> Void) -> String? {
        do {
            try body()
        } catch ProtobufDecodingError.underlying(.missingRequired(let path)) {
            return path
        } catch ProtobufEncodingError.underlying(.missingRequired(let path)) {
            return path
        } catch {
            return "\(error)"
        }
        return nil
    }

    @Test func `groups decode from protoc's bytes and encode to them`() throws {
        let bytes = try TestResource.bytes("groups")
        #expect(try decode(GroupHolder.self, bytes) == GroupHolder.sample)
        #expect(try ProtobufEncoder().encodeToBytes(GroupHolder.sample) == bytes)
    }

    @Test func `a group given twice merges, and a group with another wire type is unknown`() throws {
        // Data {group_int32: 1}, then Data {group_uint32: 2}
        let twice: [UInt8] = [0xCB, 0x0C, 0xD0, 0x0C, 0x01, 0xCC, 0x0C, 0xCB, 0x0C, 0xD8, 0x0C, 0x02, 0xCC, 0x0C]
        #expect(try decode(GroupHolder.self, twice).data == GroupData(groupInt32: 1, groupUint32: 2))
        let delimited: [UInt8] = [0xCA, 0x0C, 0x00]
        let decoded = try decode(GroupHolder.self, delimited)
        #expect(decoded.data == nil)
        #expect(decoded.unknownFields.bytes == delimited)
    }

    @Test func `a group that does not close, or closes with another number, is refused`() {
        #expect(throws: (any Error).self) { try decode(GroupHolder.self, [0xCB, 0x0C, 0xD0, 0x0C, 0x01]) }
        #expect(throws: (any Error).self) { try decode(GroupHolder.self, [0xCB, 0x0C, 0xD0, 0x0C, 0x01, 0xE4, 0x0C]) }
    }

    @Test func `required fields present, even at their defaults, decode from protoc's bytes and encode to them`() throws
    {
        let bytes = try TestResource.bytes("required")
        let value = RequiredHolder(a: 0, child: RequiredHolder(a: 1), many: [RequiredHolder(a: 2)])
        #expect(try decode(RequiredHolder.self, bytes) == value)
        #expect(try ProtobufEncoder().encodeToBytes(value) == bytes)
    }

    @Test func `a missing required field is refused with its path, decoding and encoding`() {
        #expect(missing { _ = try decode(RequiredHolder.self, []) } == "a")
        #expect(missing { _ = try decode(RequiredHolder.self, [0x08, 0x01, 0x12, 0x00]) } == "child.a")
        let many: [UInt8] = [0x08, 0x01, 0x1A, 0x02, 0x08, 0x02, 0x1A, 0x00]
        #expect(missing { _ = try decode(RequiredHolder.self, many) } == "many[1].a")
        #expect(
            missing { _ = try ProtobufEncoder().encodeToBytes(RequiredHolder(a: 1, child: RequiredHolder())) }
                == "child.a")
    }

    @Test func `a required field supplied by a later occurrence of its message is present`() throws {
        // a = 1, child {}, child {a: 2}
        let bytes: [UInt8] = [0x08, 0x01, 0x12, 0x00, 0x12, 0x02, 0x08, 0x02]
        #expect(try decode(RequiredHolder.self, bytes).child == RequiredHolder(a: 2))
    }
}
