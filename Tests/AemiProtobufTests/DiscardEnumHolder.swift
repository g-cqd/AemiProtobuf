import AemiProtobuf

/// ``EnumHolder``'s closed fields, dropping what it does not know.
@ProtoMessage(unknownFields: .discard)
struct DiscardEnumHolder: Equatable {
    @ProtoField(1, .enumeration) var color: Color = .red
    @ProtoField(2, .enumeration) var colors: [Color] = []
}
