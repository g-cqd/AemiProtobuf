import AemiJSON

@JSONCodable
public struct MacroJSONProfile: Codable, Equatable, Sendable {
    var bio: String
    var company: String?
    var publicRepos: Int
    var location: String?
}
