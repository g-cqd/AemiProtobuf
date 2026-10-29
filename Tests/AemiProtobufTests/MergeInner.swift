import AemiProtobuf

/// `Resources/merge.proto`'s `Inner`.
@ProtoMessage
struct MergeInner: Equatable {
    @ProtoField(1) var a: Int32 = 0
    @ProtoField(2) var b: Int32 = 0
}
