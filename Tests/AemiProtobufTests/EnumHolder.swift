import AemiProtobuf

/// Closed (`Color`) and open (`OpenColor`) enumerations, singular and packed.
@ProtoMessage
struct EnumHolder: Equatable {
    @ProtoField(1, .enumeration) var color: Color = .red
    @ProtoField(2, .enumeration) var colors: [Color] = []
    @ProtoField(3, .enumeration) var open: OpenColor = .red
    @ProtoField(4, .enumeration) var opens: [OpenColor] = []
}
