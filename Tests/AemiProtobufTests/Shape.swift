import AemiProtobuf

/// `Resources/oneof.proto`'s `Shape`.
@ProtoMessage
struct Shape: Equatable {
    @ProtoOneofField var kind: ShapeKind? = nil
    @ProtoField(9) var name: String = ""
}
