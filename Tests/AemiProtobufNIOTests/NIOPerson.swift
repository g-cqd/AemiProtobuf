import AemiProtobufNIO

@ProtoMessage
struct NIOPerson: Equatable, Sendable {
    @ProtoField(1) var id: Int64 = 0
    @ProtoField(2) var name: String = ""
    @ProtoField(3) var tags: [String] = []
}
