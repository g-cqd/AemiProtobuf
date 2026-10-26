import AemiProtobuf

@ProtoMessage
struct MacroAddress: Equatable {
    @ProtoField(1) var street: String = ""
    @ProtoField(2) var city: String = ""
    @ProtoField(3) var zip: Int32 = 0
}
