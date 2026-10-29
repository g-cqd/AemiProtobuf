import AemiProtobuf

/// The same fields as ``UnknownHolder``, dropping what it does not declare.
@ProtoMessage(unknownFields: .discard)
struct DiscardHolder: Equatable {
    @ProtoField(3) var flag: Bool = false
    @ProtoField(4) var text: String = ""
}
