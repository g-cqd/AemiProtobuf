import AemiProtobuf

/// `Resources/merge.proto`'s `Holder`.
@ProtoMessage
struct MergeHolder: Equatable {
    @ProtoField(1) var pair: MergePair = MergePair()
    @ProtoField(2) var maybe: MergePair? = nil
    @ProtoField(3) var many: [MergePair] = []
    @ProtoField(4) var last: Int32 = 0

    /// What `Resources/merge.txt` (protoc's decoding of `merge.bin`, two encodings one after the other) describes.
    static let merged = MergeHolder(
        pair: MergePair(a: 1, b: 2, list: [1, 2], inner: MergeInner(a: 5, b: 6)), maybe: MergePair(a: 3, b: 4),
        many: [MergePair(a: 1), MergePair(b: 2)], last: 2)
}
