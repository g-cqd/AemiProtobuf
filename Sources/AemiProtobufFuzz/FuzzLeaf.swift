import AemiProtobuf

@ProtoMessage
struct FuzzLeaf: Equatable {
    @ProtoField(1) var name: String = ""
    @ProtoField(2, .sint64) var delta: Int64 = 0
}
