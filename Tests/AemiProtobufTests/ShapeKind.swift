import AemiProtobuf

/// `Resources/oneof.proto`'s `oneof kind`.
@ProtoOneof
enum ShapeKind: Equatable {
    @ProtoField(1) case circle(Int32)
    @ProtoField(2) case label(String)
    @ProtoField(3) case leaf(Leaf)
    @ProtoField(4, .sint64) case delta(Int64)
    @ProtoField(5, .enumeration) case color(Color)
}
