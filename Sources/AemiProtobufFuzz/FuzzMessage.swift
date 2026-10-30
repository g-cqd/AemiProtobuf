import AemiProtobuf

@ProtoMessage
struct FuzzMessage: Equatable {
    @ProtoField(1) var id: UInt64 = 0
    @ProtoField(2) var text: String? = nil
    @ProtoField(3) var bytes: [UInt8] = []
    @ProtoField(4, .fixed32) var fixed: [UInt32] = []
    @ProtoField(5) var values: [Double] = []
    @ProtoField(6) var strings: [String] = []
    @ProtoField(7) var leaf: FuzzLeaf? = nil
    @ProtoField(8) var leaves: [FuzzLeaf] = []
    @ProtoField(9, key: .sint32) var map: [Int32: FuzzLeaf] = [:]
    @ProtoOneofField var choice: FuzzChoice? = nil
    @ProtoField(13) @Indirect var child: FuzzMessage? = nil
    @ProtoField(14, .group) var group: FuzzLeaf? = nil
    @ProtoField(15, packed: false) var flags: [Bool] = []
}
