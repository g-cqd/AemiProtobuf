import AemiProtobuf

/// A message that keeps what it does not declare (the default).
@ProtoMessage
struct UnknownHolder: Equatable {
    @ProtoField(3) var flag: Bool = false
    @ProtoField(4) var text: String = ""
}
