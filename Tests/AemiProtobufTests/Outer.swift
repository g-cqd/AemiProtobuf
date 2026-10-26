import Foundation

struct Outer: Codable, Equatable {
    var id: Int64 = 0
    var name: String?
    var ratio = 0.0
    var tags: [String] = []
    var samples: [Int32] = []
    var inner = Inner()
    var items: [Inner] = []
    var blob = Data()
    var level = Level.low
    var maybeZero: Int32?
    var ok = false
    var small: UInt8 = 0

    enum CodingKeys: Int, CodingKey {
        case id = 1
        case name = 2
        case ratio = 3
        case tags = 4
        case samples = 5
        case inner = 6
        case items = 7
        case blob = 8
        case level = 9
        case maybeZero = 10
        case ok = 11
        case small = 12
    }

    /// The value `Resources/outer.txt` describes.
    static let sample = Outer(
        id: 150, name: "Ann", ratio: 0.5, tags: ["a", "b"], samples: [1, -2, 300], inner: Inner(label: "in", count: 5),
        items: [Inner(label: "x", count: 1), Inner(label: "y")], blob: Data([1, 2, 255]), level: .high, maybeZero: 0,
        ok: true, small: 7)
}
