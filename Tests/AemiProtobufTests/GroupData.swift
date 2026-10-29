import AemiProtobuf

/// `Resources/proto2.proto`'s `GroupHolder.Data` group.
@ProtoMessage
struct GroupData: Equatable {
    @ProtoField(202) var groupInt32: Int32? = nil
    @ProtoField(203) var groupUint32: UInt32? = nil
}
