public import AemiProtobuf

/// `message Strings { repeated string values = 1; }`.
@ProtoMessage
public struct RepeatedStrings: Equatable {
    @ProtoField(1) public var values: [String] = []
}

extension RepeatedStrings {
    public init(_ values: [String]) { self.init(values: values) }
}
