import AemiProtobuf
import AemiProtobufCore
import Foundation
import Testing

struct CodableAdversarialTests {
    private let decoder = ProtobufDecoder()
    private let encoder = ProtobufEncoder()

    @Test func `nested messages given twice are merged`() throws {
        // field 6 twice: {label: "in"} then {count: 5}
        let bytes: [UInt8] = [0x32, 0x04, 0x0A, 0x02, 0x69, 0x6E, 0x32, 0x02, 0x10, 0x05]
        #expect(try decoder.decode(Outer.self, fromBytes: bytes).inner == Inner(label: "in", count: 5))
    }

    @Test func `the last occurrence of a scalar wins and unknown fields are skipped`() throws {
        let bytes: [UInt8] = [0x08, 0x01, 0x78, 0x09, 0x08, 0x02]  // id=1, unknown field 15, id=2
        #expect(try decoder.decode(Outer.self, fromBytes: bytes).id == 2)
    }

    @Test func `packed and unpacked repeated scalars mix in order`() throws {
        let bytes: [UInt8] = [0x28, 0x01, 0x2A, 0x02, 0x02, 0x03]  // 1, then packed [2, 3]
        #expect(try decoder.decode(Outer.self, fromBytes: bytes).samples == [1, 2, 3])
    }

    @Test(arguments: [
        [UInt8]([0x08, 0x00, 0x11, 0, 0, 0, 0, 0, 0, 0, 0, 0x00]),  // truncated trailing tag value
        [0x12, 0x01, 0xFF],  // string that is not UTF-8
        [0x09, 1, 2, 3, 4, 5, 6, 7, 8],  // id as fixed64 where a varint is declared
        [0x0A, 0x05, 0x61],  // length past the end
        [0x60, 0xAC, 0x02],  // small = 300 does not fit UInt8
        [0x32, 0x02, 0x0A, 0x80]  // truncated inside a nested message
    ])
    func `malformed or mismatched input throws instead of trapping`(bytes: [UInt8]) {
        #expect(throws: (any Error).self) { try decoder.decode(Outer.self, fromBytes: bytes) }
    }

    @Test func `random buffers never trap`() throws {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> UInt8 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return UInt8(truncatingIfNeeded: state >> 33)
        }
        var accepted = 0
        for _ in 0 ..< 3_000 {
            let bytes = (0 ..< Int(next() % 40)).map { _ in next() }
            if (try? decoder.decode(Outer.self, fromBytes: bytes)) != nil { accepted += 1 }
        }
        #expect(accepted > 0, "the generator must also produce some valid messages")
    }

    @Test func `nesting at the limit round-trips and one more level is refused both ways`() throws {
        let limits = WireLimits(maxDepth: 10)
        let encoder = ProtobufEncoder(limits: limits)
        let decoder = ProtobufDecoder(limits: limits)
        let ok = Node.chain(depth: 9)
        #expect(try decoder.decode(Node.self, fromBytes: try encoder.encodeToBytes(ok)) == ok)
        #expect(throws: (any Error).self) { try encoder.encodeToBytes(Node.chain(depth: 11)) }
        let deep = try ProtobufEncoder().encodeToBytes(Node.chain(depth: 11))
        #expect(throws: (any Error).self) { try decoder.decode(Node.self, fromBytes: deep) }
    }

    @Test func `a dictionary field is refused rather than trapping`() {
        struct WithMap: Codable { var map: [String: Int32] = ["a": 1] }
        #expect(throws: (any Error).self) { try encoder.encodeToBytes(WithMap()) }
    }

    @Test func `a top-level scalar and a top-level array of non-message values are refused`() {
        #expect(throws: (any Error).self) { try encoder.encodeToBytes(5) }
        #expect(throws: (any Error).self) { try encoder.encodeToBytes(["a", "b"]) }
    }

    @Test func `a message larger than the limit is refused`() {
        let small = ProtobufEncoder(limits: WireLimits(maxDepth: 10, maxMessageBytes: 4))
        var value = Outer()
        value.inner.label = "this label alone exceeds four bytes"
        #expect(throws: (any Error).self) { try small.encodeToBytes(value) }
    }

    @Test func `extreme scalar values survive a round trip`() throws {
        struct Scalars: Codable, Equatable {
            var a: Int64 = .min
            var b: Int32 = .min
            var c: UInt64 = .max
            var d = Double.infinity
            var e = Float.leastNonzeroMagnitude
            var f: Int8 = -128
            var g: UInt16 = .max
            enum CodingKeys: Int, CodingKey {
                case a = 1
                case b, c, d, e, f, g
            }
        }
        let value = Scalars()
        #expect(try decoder.decode(Scalars.self, fromBytes: try encoder.encodeToBytes(value)) == value)
    }

    @Test func `keys with no integer value are refused`() {
        struct Bad: Codable { var name = "x" }
        #expect(throws: (any Error).self) { try encoder.encodeToBytes(Bad()) }
    }
}
