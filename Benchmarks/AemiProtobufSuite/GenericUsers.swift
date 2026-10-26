/// The same schema with no macro, so the coders take the generic `Codable` path.
struct GenericUsers: Codable, Equatable {
    var users: [GenericUser] = []

    enum CodingKeys: Int, CodingKey { case users = 1 }

    init(_ macro: MacroUsers) {
        users = macro.users.map(GenericUser.init)
    }
}
