public import AemiProtobuf

/// `message Doubles { repeated double values = 1; }`: one packed record.
@ProtoMessage
public struct PackedDoubles: Equatable {
    @ProtoField(1) public var values: [Double] = []
}

extension PackedDoubles {
    public init(_ values: [Double]) { self.init(values: values) }
}
