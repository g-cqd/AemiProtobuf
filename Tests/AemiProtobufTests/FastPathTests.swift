import AemiProtobuf
import AemiProtobufCore
import Foundation
import Testing

struct FastPathTests {
    @Test func `fast path encodes and decodes round-trip via ProtobufEncoder and ProtobufDecoder`() throws {
        let user = FastUser(
            id: 150, name: "ann", email: "a@b.c", active: true, score: 1.5,
            tags: ["x", "y"], samples: [1, 300, -1],
            address: FastAddress(street: "s", city: "c", zip: 7),
            delta: -3, stamp: 9)

        let encoder = ProtobufEncoder()
        let decoder = ProtobufDecoder()

        let bytes = try encoder.encode(user)
        #expect(!bytes.isEmpty)

        let decoded = try decoder.decode(FastUser.self, from: bytes)
        #expect(decoded == user)
    }

    @Test func `fast path array round-trips correctly`() throws {
        let users = [
            FastUser(id: 1, name: "u1"),
            FastUser(id: 2, name: "u2")
        ]
        let encoder = ProtobufEncoder()
        let decoder = ProtobufDecoder()

        let bytes = try encoder.encode(users)
        let decoded = try decoder.decode([FastUser].self, from: bytes)
        #expect(decoded == users)
    }
}
