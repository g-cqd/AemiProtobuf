import AemiProtobuf

@ProtoMessage
struct MacroUsers: Equatable {
    @ProtoField(1) var users: [MacroUser] = []

    init() {}

    init(_ records: [UserRecord]) {
        users = records.map { r in
            MacroUser(
                id: r.id, name: r.name, email: r.email, active: r.active, score: r.score, tags: r.tags,
                samples: r.samples,
                address: MacroAddress(street: r.street, city: r.city, zip: r.zip), delta: r.delta, stamp: r.stamp)
        }
    }
}
