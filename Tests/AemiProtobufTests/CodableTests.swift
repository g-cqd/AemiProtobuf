import AemiProtobuf
import AemiProtobufCore
import Foundation
import Testing

struct CodableTests {
    @Test func `generic Codable struct encodes and decodes round-trip with integer CodingKeys`() throws {
        let person = CodablePerson(
            id: 42, name: "Alice", email: "alice@example.com",
            active: true, score: 99.5, tags: ["admin", "staff"], age: 30)

        let encoder = ProtobufEncoder()
        let decoder = ProtobufDecoder()

        let bytes = try encoder.encode(person)
        #expect(!bytes.isEmpty)

        let decoded = try decoder.decode(CodablePerson.self, from: bytes)
        #expect(decoded == person)
    }

    @Test func `absent optional decodes as nil`() throws {
        let person = CodablePerson(
            id: 1, name: "Bob", email: "bob@example.com",
            active: false, score: 12.0, tags: [], age: nil)

        let encoder = ProtobufEncoder()
        let decoder = ProtobufDecoder()

        let bytes = try encoder.encode(person)
        let decoded = try decoder.decode(CodablePerson.self, from: bytes)
        #expect(decoded == person)
        #expect(decoded.age == nil)
    }

    @Test func `type without integer CodingKeys throws unsupportedKeys error`() throws {
        struct StringKeysPerson: Codable {
            var name: String
            enum CodingKeys: String, CodingKey {
                case name = "name"
            }
        }

        let encoder = ProtobufEncoder()
        #expect(throws: ProtobufEncodingError.self) {
            _ = try encoder.encode(StringKeysPerson(name: "Test"))
        }
    }
}
