/// Same schema as `ProtoProfile`, with no fast-path conformance: measures the generic `Codable` container path.
public struct CodableProtoProfile: Codable, Equatable {
    public var bio = ""
    public var company: String?
    public var publicRepos: Int64 = 0
    public var location: String?

    enum CodingKeys: Int, CodingKey {
        case bio = 1
        case company = 2
        case publicRepos = 3
        case location = 4
    }
}
