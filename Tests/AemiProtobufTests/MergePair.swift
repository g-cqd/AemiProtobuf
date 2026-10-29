import AemiProtobuf

/// `Resources/merge.proto`'s `Pair`.
@ProtoMessage
struct MergePair: Equatable {
    @ProtoField(1) var a: Int32 = 0
    @ProtoField(2) var b: Int32 = 0
    @ProtoField(3) var list: [Int32] = []
    @ProtoField(4) var inner: MergeInner = MergeInner()
}
