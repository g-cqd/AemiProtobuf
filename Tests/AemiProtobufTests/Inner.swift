struct Inner: Codable, Equatable {
    var label = ""
    var count: Int32 = 0

    enum CodingKeys: Int, CodingKey {
        case label = 1
        case count = 2
    }
}
