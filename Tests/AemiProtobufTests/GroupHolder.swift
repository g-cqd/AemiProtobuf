import AemiProtobuf

/// `Resources/proto2.proto`'s `GroupHolder`: a singular and a repeated group.
@ProtoMessage
struct GroupHolder: Equatable {
    @ProtoField(1) var after: Int32? = nil
    @ProtoField(201, .group) var data: GroupData? = nil
    @ProtoField(204, .group) var items: [GroupItem] = []

    /// What `Resources/groups.bin` holds.
    static let sample = GroupHolder(
        after: 7, data: GroupData(groupInt32: -1, groupUint32: 3), items: [GroupItem(value: 1), GroupItem()])
}
