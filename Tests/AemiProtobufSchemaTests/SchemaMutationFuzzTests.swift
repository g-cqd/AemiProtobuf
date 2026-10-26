import AemiProtobufCore
import AemiProtobufSchema
import Foundation
import Testing

/// Deterministic fuzzing of the schema tools: every one-byte change and prefix of the protoc descriptor sets, damaged `.proto`
/// text, and damaged wire bytes validated against a descriptor. Each call may accept or refuse and must never trap.
struct SchemaMutationFuzzTests {
    private func resource(_ name: String, _ ext: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources"))
        return try Data(contentsOf: url)
    }

    @Test func `descriptor sets with any one byte changed or cut short decode or throw`() throws {
        for name in ["sample", "oneof"] {
            let bytes = [UInt8](try resource(name, "pb"))
            for index in bytes.indices {
                for change in [UInt8(0x01), 0x80, 0xFF] {
                    var mutated = bytes
                    mutated[index] ^= change
                    _ = try? FileDescriptorSet.decode(from: mutated)
                }
            }
            for length in 0 ... bytes.count { _ = try? FileDescriptorSet.decode(from: Array(bytes[..<length])) }
        }
    }

    @Test func `proto text with a character deleted, doubled or replaced parses or throws`() throws {
        let text = String(decoding: try resource("oneof", "proto"), as: UTF8.self)
        let scalars = Array(text.unicodeScalars)
        var refused = 0
        for index in scalars.indices {
            var deleted = scalars
            deleted.remove(at: index)
            var doubled = scalars
            doubled.insert(scalars[index], at: index)
            var replaced = scalars
            replaced[index] = "}"
            for variant in [deleted, doubled, replaced] {
                var source = String.UnicodeScalarView()
                source.append(contentsOf: variant)
                do { _ = try ProtoParser().parse(String(source)) } catch { refused += 1 }
            }
        }
        #expect(refused > 0, "some damage must be noticed")
    }

    @Test func `damaged wire bytes validate to findings without trapping`() throws {
        let descriptor = MessageDescriptor(
            name: "M",
            fields: [
                FieldDescriptor(name: "a", number: 1, type: .int64),
                FieldDescriptor(name: "b", number: 2, type: .string),
                FieldDescriptor(name: "c", number: 3, label: .repeated, type: .int32),
                FieldDescriptor(name: "d", number: 4, label: .repeated, type: .double),
                FieldDescriptor(name: "e", number: 5, label: .required, type: .message)
            ])
        var w = WireWriter()
        w.appendTag(1, .varint)
        w.appendVarint(150)
        w.appendTag(2, .lengthDelimited)
        w.appendString("hello")
        w.appendPackedVarints(field: 3, [1, 300, -1] as [Int32])
        w.appendPackedLittleEndian(field: 4, [1.5, 2.5])
        w.appendTag(5, .lengthDelimited)
        w.appendBytes([8, 1])
        let valid = w.bytes
        #expect(WireValidator().validate(bytes: valid, against: descriptor).isEmpty)
        var flagged = 0
        for index in valid.indices {
            for change in [UInt8(0x01), 0x80, 0xFF] {
                var mutated = valid
                mutated[index] ^= change
                if !WireValidator().validate(bytes: mutated, against: descriptor).isEmpty { flagged += 1 }
            }
        }
        for length in 0 ... valid.count {
            _ = WireValidator().validate(bytes: Array(valid[..<length]), against: descriptor)
        }
        #expect(flagged > 0)
    }
}
