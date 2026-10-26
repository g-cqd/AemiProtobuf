struct GenericUser: Codable, Equatable {
    var id: Int64 = 0
    var name = ""
    var email = ""
    var active = false
    var score = 0.0
    var tags: [String] = []
    var samples: [Int32] = []
    var address = GenericAddress()
    var delta: Int32 = 0
    var stamp: UInt64 = 0

    enum CodingKeys: Int, CodingKey {
        case id = 1
        case name, email, active, score, tags, samples, address, delta, stamp
    }

    init(_ m: MacroUser) {
        (id, name, email, active, score, tags, samples) = (m.id, m.name, m.email, m.active, m.score, m.tags, m.samples)
        address = GenericAddress(street: m.address.street, city: m.address.city, zip: m.address.zip)
        (delta, stamp) = (m.delta, m.stamp)
    }
}
