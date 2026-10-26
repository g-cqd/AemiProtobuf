public import AemiProtobuf

/// `message Users { repeated User users = 1; }`: the root a top-level list needs, since protobuf has no top-level array.
@ProtoMessage
public struct ProtoUsers: Equatable {
    @ProtoField(1) public var users: [ProtoUser] = []
}

extension ProtoUsers {
    public init(_ records: [Record]) { self.init(users: records.map(ProtoUser.init)) }

    public var records: [Record] { users.map(\.record) }
}
