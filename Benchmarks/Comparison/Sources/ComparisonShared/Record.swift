/// The logical record both formats carry: a keyed, optional-heavy, nested object (the shape people complain about for JSON).
public struct Record: Equatable, Sendable {
    public var id: Int
    public var login: String
    public var name: String?
    public var email: String?
    public var followers: Int
    public var following: Int
    public var isAdmin: Bool
    public var score: Double
    public var tags: [String]
    public var bio: String
    public var company: String?
    public var publicRepos: Int
    public var location: String?
}
