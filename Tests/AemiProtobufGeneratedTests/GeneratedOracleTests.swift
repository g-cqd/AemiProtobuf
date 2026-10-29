import AemiProtobuf
import Foundation
import Testing

/// Roadmap 0028: what protoc-gen-aemi wrote for the test protos reads protoc's bytes and writes them back.
@Suite struct GeneratedOracleTests {
    private func bytes(_ name: String) throws -> [UInt8] {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "bin", subdirectory: "Resources"))
        return [UInt8](try Data(contentsOf: url))
    }

    private func roundTrip<T: AemiProtoFastEncodable & AemiProtoFastDecodable & Codable & Equatable>(
        _ name: String, _ value: T
    ) throws {
        let protoc = try bytes(name)
        #expect(try ProtobufDecoder().decode(T.self, fromBytes: protoc) == value)
        #expect(try ProtobufEncoder().encodeToBytes(value) == protoc)
    }

    @Test func `every scalar kind, nested, optional and repeated`() throws {
        var kinds = Gen_Kinds_Kinds()
        kinds.aInt32 = -5
        kinds.aInt64 = -9_000_000_000
        kinds.aUint32 = 4_000_000_000
        kinds.aUint64 = 18_000_000_000_000_000_000
        kinds.aSint32 = -300
        kinds.aSint64 = -5_000_000_000
        kinds.aFixed32 = 7
        kinds.aFixed64 = 8_000_000_000
        kinds.aSfixed32 = -9
        kinds.aSfixed64 = -10_000_000_000
        kinds.aBool = true
        kinds.aFloat = 1.5
        kinds.aDouble = -2.25
        kinds.aString = "héllo"
        kinds.aBytes = [0, 255]
        kinds.color = .blue
        kinds.leaf = Gen_Kinds_Leaf(name: "L")
        kinds.maybe = 0
        kinds.maybeLeaf = Gen_Kinds_Leaf()
        kinds.rSint32 = [-1, 2, -3]
        kinds.rFixed64 = [1, 2]
        kinds.rDouble = [0.5, -0.5]
        kinds.rBool = [true, false]
        kinds.rColor = [.green, .blue]
        kinds.rString = ["a", ""]
        kinds.rBytes = [[120]]
        kinds.rLeaf = [Gen_Kinds_Leaf(name: "one"), Gen_Kinds_Leaf()]
        try roundTrip("kinds", kinds)
    }

    @Test func `maps of every key and value class`() throws {
        var maps = Gen_Maps_Maps()
        maps.names = [2: "two", -1: "minus", 0: ""]
        maps.entries = ["b": Gen_Maps_Entry(label: "B", count: 2), "a": Gen_Maps_Entry()]
        maps.shades = [-5: .light, 3: .dark]
        maps.flags = [true: 1.5, false: 0]
        maps.blobs = [7: [1, 255]]
        maps.counts = ["é": 1, "z": -2]
        try roundTrip("maps", maps)
    }

    @Test func `oneof members, a message member and one at its default`() throws {
        try roundTrip("oneof-leaf", Gen_Oneof_Shape(kind: .leaf(Gen_Oneof_Leaf(name: "L")), name: "s"))
        try roundTrip("oneof-delta", Gen_Oneof_Shape(kind: .delta(-3)))
        try roundTrip("oneof-zero", Gen_Oneof_Shape(kind: .circle(0)))
    }

    @Test func `proto2 groups and required fields, with a message that holds itself`() throws {
        var groups = Gen_Proto2_GroupHolder()
        groups.after = 7
        groups.data = Gen_Proto2_GroupHolder.Data(groupInt32: -1, groupUint32: 3)
        groups.item = [Gen_Proto2_GroupHolder.Item(value: 1), Gen_Proto2_GroupHolder.Item()]
        try roundTrip("groups", groups)
        try roundTrip(
            "required",
            Gen_Proto2_Required(a: 0, child: Gen_Proto2_Required(a: 1), many: [Gen_Proto2_Required(a: 2)]))
        #expect(throws: (any Error).self) { try ProtobufDecoder().decode(Gen_Proto2_Required.self, fromBytes: []) }
    }

    @Test func `proto2 repeated numbers are expanded unless declared packed`() throws {
        try roundTrip("expanded", Gen_Packed_Expanded(numbers: [1, 300], deltas: [-1, 2], flags: [true, false]))
    }

    @Test func `message fields given twice merge`() throws {
        let decoded = try ProtobufDecoder().decode(Gen_Merge_Holder.self, fromBytes: bytes("merge"))
        #expect(decoded.pair?.list == [1, 2])
        #expect(decoded.pair?.inner == Gen_Merge_Inner(a: 5, b: 6))
        #expect(decoded.maybe == Gen_Merge_Pair(a: 3, b: 4))
        #expect(decoded.last == 2)
    }

    @Test func `an open enumeration keeps a number it has no case for`() throws {
        let decoded = try ProtobufDecoder().decode(Gen_Kinds_Kinds.self, fromBytes: [0x80, 0x01, 0x07])
        #expect(decoded.color == .unrecognized(7))
        #expect(try ProtobufEncoder().encodeToBytes(decoded) == [0x80, 0x01, 0x07])
    }
}
