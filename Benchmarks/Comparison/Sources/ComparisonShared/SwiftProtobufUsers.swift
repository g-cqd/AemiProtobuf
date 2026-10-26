import SwiftProtobuf

/// Conversions between the logical `Record` and swift-protobuf's generated `User`/`Users`.
public enum SwiftProtobufUsers {
    public static func make(_ records: [Record]) -> Users {
        var users = Users()
        users.users = records.map { r in
            var u = User()
            u.id = Int64(r.id)
            u.login = r.login
            if let name = r.name { u.name = name }
            if let email = r.email { u.email = email }
            u.followers = Int64(r.followers)
            u.following = Int64(r.following)
            u.isAdmin = r.isAdmin
            u.score = r.score
            u.tags = r.tags
            u.profile.bio = r.bio
            if let company = r.company { u.profile.company = company }
            u.profile.publicRepos = Int64(r.publicRepos)
            if let location = r.location { u.profile.location = location }
            return u
        }
        return users
    }

    public static func records(_ users: Users) -> [Record] {
        users.users.map { u in
            Record(
                id: Int(u.id), login: u.login, name: u.hasName ? u.name : nil, email: u.hasEmail ? u.email : nil,
                followers: Int(u.followers), following: Int(u.following), isAdmin: u.isAdmin, score: u.score,
                tags: u.tags, bio: u.profile.bio, company: u.profile.hasCompany ? u.profile.company : nil,
                publicRepos: Int(u.profile.publicRepos), location: u.profile.hasLocation ? u.profile.location : nil)
        }
    }
}
