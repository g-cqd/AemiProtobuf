public import AemiProtobuf

/// A flat message of 10 `int32` fields, to see whether decoding cost grows with the number of fields a message declares.
@ProtoMessage
public struct Wide10: Equatable {
    @ProtoField(1) public var f1: Int32 = 0
    @ProtoField(2) public var f2: Int32 = 0
    @ProtoField(3) public var f3: Int32 = 0
    @ProtoField(4) public var f4: Int32 = 0
    @ProtoField(5) public var f5: Int32 = 0
    @ProtoField(6) public var f6: Int32 = 0
    @ProtoField(7) public var f7: Int32 = 0
    @ProtoField(8) public var f8: Int32 = 0
    @ProtoField(9) public var f9: Int32 = 0
    @ProtoField(10) public var f10: Int32 = 0
}

extension Wide10 {
    /// Every field set, so every field is written and read.
    public static var filled: Wide10 {
        Wide10(
            f1: Int32(1), f2: Int32(2), f3: Int32(3), f4: Int32(4), f5: Int32(5), f6: Int32(6), f7: Int32(7),
            f8: Int32(8), f9: Int32(9), f10: Int32(10))
    }
}
