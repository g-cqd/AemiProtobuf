import AemiProtobuf
import Foundation

/// `Resources/kinds.proto`: every kind the macro writes.
@ProtoMessage
struct Kinds: Equatable {
    @ProtoField(1) var aInt32: Int32 = 0
    @ProtoField(2) var aInt64: Int64 = 0
    @ProtoField(3) var aUint32: UInt32 = 0
    @ProtoField(4) var aUint64: UInt64 = 0
    @ProtoField(5, .sint32) var aSint32: Int32 = 0
    @ProtoField(6, .sint64) var aSint64: Int64 = 0
    @ProtoField(7, .fixed32) var aFixed32: UInt32 = 0
    @ProtoField(8, .fixed64) var aFixed64: UInt64 = 0
    @ProtoField(9, .sfixed32) var aSfixed32: Int32 = 0
    @ProtoField(10, .sfixed64) var aSfixed64: Int64 = 0
    @ProtoField(11) var aBool: Bool = false
    @ProtoField(12) var aFloat: Float = 0
    @ProtoField(13) var aDouble: Double = 0
    @ProtoField(14) var aString: String = ""
    @ProtoField(15) var aBytes: Data = Data()
    @ProtoField(16, .enumeration) var color: Color = .red
    @ProtoField(17) var leaf: Leaf = Leaf()
    @ProtoField(18) var maybe: Int32? = nil
    @ProtoField(19) var maybeLeaf: Leaf? = nil
    @ProtoField(20, .sint32) var rSint32: [Int32] = []
    @ProtoField(21, .fixed64) var rFixed64: [UInt64] = []
    @ProtoField(22) var rDouble: [Double] = []
    @ProtoField(23) var rBool: [Bool] = []
    @ProtoField(24, .enumeration) var rColor: [Color] = []
    @ProtoField(25) var rString: [String] = []
    @ProtoField(26) var rBytes: [Data] = []
    @ProtoField(27) var rLeaf: [Leaf] = []

    /// The value `Resources/kinds.txt` describes.
    static let sample = Kinds(
        aInt32: -5, aInt64: -9_000_000_000, aUint32: 4_000_000_000, aUint64: 18_000_000_000_000_000_000, aSint32: -300,
        aSint64: -5_000_000_000, aFixed32: 7, aFixed64: 8_000_000_000, aSfixed32: -9, aSfixed64: -10_000_000_000,
        aBool: true, aFloat: 1.5, aDouble: -2.25, aString: "héllo", aBytes: Data([0, 255]), color: .blue,
        leaf: Leaf(name: "L"), maybe: 0, maybeLeaf: Leaf(), rSint32: [-1, 2, -3], rFixed64: [1, 2],
        rDouble: [0.5, -0.5],
        rBool: [true, false], rColor: [.green, .blue], rString: ["a", ""], rBytes: [Data([120])],
        rLeaf: [Leaf(name: "one"), Leaf()])
}
