import AemiProtobuf

@ProtoMessage
struct Leaf: Equatable {
    @ProtoField(1) var name: String = ""
}
