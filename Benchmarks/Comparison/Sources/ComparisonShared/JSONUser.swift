public struct JSONUser: Codable, Equatable, Sendable {
    public var id: Int
    public var login: String
    public var name: String?
    public var email: String?
    public var followers: Int
    public var following: Int
    public var isAdmin: Bool
    public var score: Double
    public var tags: [String]
    public var profile: JSONProfile

    public init(_ r: Record) {
        id = r.id
        login = r.login
        name = r.name
        email = r.email
        followers = r.followers
        following = r.following
        isAdmin = r.isAdmin
        score = r.score
        tags = r.tags
        profile = JSONProfile(bio: r.bio, company: r.company, publicRepos: r.publicRepos, location: r.location)
    }

    public var record: Record {
        Record(
            id: id, login: login, name: name, email: email, followers: followers, following: following,
            isAdmin: isAdmin,
            score: score, tags: tags, bio: profile.bio, company: profile.company, publicRepos: profile.publicRepos,
            location: profile.location)
    }
}
