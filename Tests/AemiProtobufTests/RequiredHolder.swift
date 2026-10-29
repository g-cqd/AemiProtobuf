import AemiProtobuf

/// `Resources/proto2.proto`'s `Required`.
@ProtoMessage
struct RequiredHolder: Equatable {
    @ProtoField(1, required: true) var a: Int32? = nil
    @ProtoField(2) @Indirect var child: RequiredHolder? = nil
    @ProtoField(3) var many: [RequiredHolder] = []
}
