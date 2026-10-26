import AemiProtobuf

/// The throughput corpus's user, as a macro message: the fast path the coders take. Plain kinds only, so the generic `Codable`
/// twin (which cannot say `sint32` or `fixed64`) writes the same bytes.
@ProtoMessage
struct MacroUser: Equatable {
    @ProtoField(1) var id: Int64 = 0
    @ProtoField(2) var name: String = ""
    @ProtoField(3) var email: String = ""
    @ProtoField(4) var active: Bool = false
    @ProtoField(5) var score: Double = 0
    @ProtoField(6) var tags: [String] = []
    @ProtoField(7) var samples: [Int32] = []
    @ProtoField(8) var address: MacroAddress = MacroAddress()
    @ProtoField(9) var delta: Int32 = 0
    @ProtoField(10) var stamp: UInt64 = 0
}
