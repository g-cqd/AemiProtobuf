public import AemiProtobuf

/// `message Int64s { repeated int64 values = 1; }`: one packed record of varints.
@ProtoMessage
public struct PackedInt64s: Equatable {
    @ProtoField(1) public var values: [Int64] = []
}

extension PackedInt64s {
    public init(_ values: [Int64]) { self.init(values: values) }
}
