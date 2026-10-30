import AemiProtobuf

@ProtoOneof
enum FuzzChoice: Equatable {
    @ProtoField(10) case number(Int32)
    @ProtoField(11) case leaf(FuzzLeaf)
    @ProtoField(12, .group) case grouped(FuzzLeaf)
}
