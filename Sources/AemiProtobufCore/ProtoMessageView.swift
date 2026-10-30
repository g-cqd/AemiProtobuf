/// A message read in place (roadmap 0006): its bytes indexed once, then fields found by number with no type, descriptor or copy.
///
/// Indexing reads every tag and length, so malformed bytes are refused up front; values are decoded only when asked for. A
/// singular read takes a field's last occurrence, as protobuf's merge does for scalars, and is `nil` when the field is absent or
/// came with another wire type. A nested message is another view over the same array, indexed when it is asked for, one level
/// deeper. ``withBytes(_:_:)`` and ``utf8Equals(_:_:)`` read a string or bytes field without making a `String` or an array.
public struct ProtoMessageView: Sendable {
    /// One occurrence of a field: a varint or fixed value, or a payload's range.
    struct Entry: Sendable {
        let number: UInt32
        let wireType: WireType
        let value: UInt64
        let payload: Range<Int>
    }

    /// The buffer the message lies in: shared with every view over it, never copied.
    public let bytes: [UInt8]
    /// Where the message lies in ``bytes``.
    public let range: Range<Int>
    let depth: Int
    let limits: WireLimits
    let entries: [Entry]
    /// Each number's last occurrence, for a message with more fields than a linear search suits.
    private let lastIndex: [UInt32: Int]?

    /// Indexes `bytes` as a message.
    /// - Throws: whatever makes the bytes malformed: ``WireError/truncated(at:)``, ``WireError/lengthOutOfBounds(declared:remaining:at:)``,
    ///   an end-group tag with no group, a group that does not close, and the like.
    public init(_ bytes: [UInt8], limits: WireLimits = .default) throws(WireError) {
        try self.init(bytes: bytes, range: 0 ..< bytes.count, depth: 0, limits: limits)
    }

    init(bytes: [UInt8], range: Range<Int>, depth: Int, limits: WireLimits) throws(WireError) {
        self.bytes = bytes
        self.range = range
        self.depth = depth
        self.limits = limits
        let entries = try WireReader.withReader(over: bytes, in: range, depth: depth, limits: limits) {
            (reader) throws(WireError) -> [Entry] in
            // A field takes two bytes at least; reserving for the common case once beats growing the array four or five times.
            var entries: [Entry] = []
            entries.reserveCapacity(min(reader.remaining / 2, 32))
            while let tag = try reader.nextTag() {
                var value: UInt64 = 0
                var payload = 0 ..< 0
                switch tag.wireType {
                    case .varint: value = try reader.readVarint()
                    case .fixed32: value = UInt64(try reader.readFixed32())
                    case .fixed64: value = try reader.readFixed64()
                    case .lengthDelimited: payload = try reader.readPayloadRange()
                    case .startGroup: payload = try reader.readGroupRange(tag)
                    case .endGroup: throw .unexpectedEndGroup(at: reader.tagOffset)
                }
                entries.append(
                    Entry(number: tag.fieldNumber.rawValue, wireType: tag.wireType, value: value, payload: payload))
            }
            return entries
        }
        self.entries = entries
        lastIndex =
            entries.count > 16
            ? Dictionary(entries.indices.map { (entries[$0].number, $0) }, uniquingKeysWith: { _, later in later })
            : nil
    }

    /// The number of field occurrences, a packed run counting once.
    public var count: Int { entries.count }

    /// Whether the field occurs at all.
    public func has(_ field: FieldNumber) -> Bool { last(field) != nil }

    /// The field's last occurrence.
    func last(_ field: FieldNumber) -> Entry? {
        if let lastIndex { return lastIndex[field.rawValue].map { entries[$0] } }
        return entries.last { $0.number == field.rawValue }
    }

    /// The field's last occurrence when it came with `wireType`.
    func last(_ field: FieldNumber, _ wireType: WireType) -> Entry? {
        guard let entry = last(field), entry.wireType == wireType else { return nil }
        return entry
    }

    /// The nested message the field holds (its last occurrence, a group included), indexed now.
    /// - Throws: a ``WireError`` if its bytes are malformed or it lies past `limits.maxDepth`.
    public func message(_ field: FieldNumber) throws(WireError) -> ProtoMessageView? {
        guard let entry = last(field), entry.wireType == .lengthDelimited || entry.wireType == .startGroup else {
            return nil
        }
        return try ProtoMessageView(bytes: bytes, range: entry.payload, depth: depth + 1, limits: limits)
    }

    /// Every occurrence of a repeated message field, in order.
    public func messages(_ field: FieldNumber) throws(WireError) -> [ProtoMessageView] {
        var views: [ProtoMessageView] = []
        for entry in entries
        where entry.number == field.rawValue && (entry.wireType == .lengthDelimited || entry.wireType == .startGroup) {
            views.append(try ProtoMessageView(bytes: bytes, range: entry.payload, depth: depth + 1, limits: limits))
        }
        return views
    }
}
