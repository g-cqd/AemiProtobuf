import AemiProtobuf

/// `Resources/packed.proto`'s `Expanded`: proto2 repeated numbers are one record per element unless declared packed.
@ProtoMessage
struct Expanded: Equatable {
    @ProtoField(1, packed: false) var numbers: [Int32] = []
    @ProtoField(2, .sint64) var deltas: [Int64] = []
    @ProtoField(3, packed: false) var flags: [Bool] = []
}
