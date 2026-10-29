/// A range of field numbers, `start` included and `end` excluded, as `DescriptorProto.ExtensionRange` and `ReservedRange` hold
/// them (an enumeration's reserved range includes its `end`; ``EnumDescriptor/reservedRanges`` says so).
public struct DescriptorRange: Sendable, Equatable {
    public var start: Int32?
    public var end: Int32?
    /// `ExtensionRangeOptions`, as protoc wrote them.
    public var options: [UInt8]?

    public init(start: Int32? = nil, end: Int32? = nil, options: [UInt8]? = nil) {
        self.start = start
        self.end = end
        self.options = options
    }
}
