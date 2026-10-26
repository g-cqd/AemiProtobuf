/// Same schema as ``ProtoUser`` with no fast-path conformance.
public struct CodableProtoUser: Codable, Equatable {
    public var id: Int64 = 0
    public var login = ""
    public var name: String?
    public var email: String?
    public var followers: Int64 = 0
    public var following: Int64 = 0
    public var isAdmin = false
    public var score = 0.0
    public var tags: [String] = []
    public var profile = CodableProtoProfile()

    enum CodingKeys: Int, CodingKey {
        case id = 1
        case login = 2
        case name = 3
        case email = 4
        case followers = 5
        case following = 6
        case isAdmin = 7
        case score = 8
        case tags = 9
        case profile = 10
    }

    public init(_ r: Record) {
        id = Int64(r.id)
        login = r.login
        name = r.name
        email = r.email
        followers = Int64(r.followers)
        following = Int64(r.following)
        isAdmin = r.isAdmin
        score = r.score
        tags = r.tags
        profile = CodableProtoProfile(
            bio: r.bio, company: r.company, publicRepos: Int64(r.publicRepos), location: r.location)
    }
}
