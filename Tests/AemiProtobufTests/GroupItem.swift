import AemiProtobuf

/// `Resources/proto2.proto`'s `GroupHolder.Item` group.
@ProtoMessage
struct GroupItem: Equatable {
    @ProtoField(205) var value: Int32? = nil
}
