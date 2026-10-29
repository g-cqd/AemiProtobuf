import AemiProtobuf

/// `Resources/maps.proto`'s `Entry`.
@ProtoMessage
struct MapEntryValue: Equatable {
    @ProtoField(1) var label: String = ""
    @ProtoField(2) var count: Int32 = 0
}
