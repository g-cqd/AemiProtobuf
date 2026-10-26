struct GenericAddress: Codable, Equatable {
    var street = ""
    var city = ""
    var zip: Int32 = 0

    enum CodingKeys: Int, CodingKey {
        case street = 1
        case city, zip
    }
}
