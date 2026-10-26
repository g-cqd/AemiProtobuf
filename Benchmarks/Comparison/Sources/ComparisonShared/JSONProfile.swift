public struct JSONProfile: Codable, Equatable, Sendable {
    public var bio: String
    public var company: String?
    public var publicRepos: Int
    public var location: String?
}
