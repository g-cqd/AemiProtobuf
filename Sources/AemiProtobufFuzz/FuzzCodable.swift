/// The generic `Codable` path.
struct FuzzCodable: Codable, Equatable {
    var id: Int64 = 0
    var name: String = ""
    var children: [FuzzCodable] = []

    enum CodingKeys: Int, CodingKey {
        case id = 1
        case name = 2
        case children = 3
    }
}
