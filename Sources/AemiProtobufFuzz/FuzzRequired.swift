import AemiProtobuf

@ProtoMessage
struct FuzzRequired: Equatable {
    @ProtoField(1, required: true) var a: Int32? = nil
    @ProtoField(2) @Indirect var child: FuzzRequired? = nil
}
