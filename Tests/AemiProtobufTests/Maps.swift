import AemiProtobuf
import Foundation

/// `Resources/maps.proto`'s `Maps`: every key class and value class.
@ProtoMessage
struct Maps: Equatable {
    @ProtoField(1) var names: [Int32: String] = [:]
    @ProtoField(2) var entries: [String: MapEntryValue] = [:]
    @ProtoField(3, key: .sint64, value: .enumeration) var shades: [Int64: Shade] = [:]
    @ProtoField(4) var flags: [Bool: Double] = [:]
    @ProtoField(5, key: .fixed32) var blobs: [UInt32: Data] = [:]
    @ProtoField(6) var counts: [String: Int64] = [:]

    /// The value `Resources/maps.txt` describes.
    static let sample = Maps(
        names: [2: "two", -1: "minus", 0: ""],
        entries: ["b": MapEntryValue(label: "B", count: 2), "a": MapEntryValue()],
        shades: [-5: .light, 3: .dark], flags: [true: 1.5, false: 0], blobs: [7: Data([1, 255])],
        counts: ["é": 1, "z": -2])
}
