struct CodablePerson: Codable, Equatable {
    var id: Int64
    var name: String
    var email: String
    var active: Bool
    var score: Double
    var tags: [String]
    var age: Int32?

    enum CodingKeys: Int, CodingKey {
        case id = 1
        case name = 2
        case email = 3
        case active = 4
        case score = 5
        case tags = 6
        case age = 7
    }
}
