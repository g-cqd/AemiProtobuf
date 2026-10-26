public struct CodableProtoUsers: Codable, Equatable {
    var users: [CodableProtoUser] = []

    enum CodingKeys: Int, CodingKey { case users = 1 }

    public init(_ records: [Record]) { users = records.map(CodableProtoUser.init) }

    public var count: Int { users.count }
}
