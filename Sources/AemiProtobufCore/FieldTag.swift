/// A field number and a wire type: the key that precedes every field on the wire (`number << 3 | wireType`).
public struct FieldTag: Hashable, Sendable {
    public let fieldNumber: FieldNumber
    public let wireType: WireType

    @inlinable public init(fieldNumber: FieldNumber, wireType: WireType) {
        self.fieldNumber = fieldNumber
        self.wireType = wireType
    }

    /// The tag as it is written: always fits 32 bits because a field number has 29.
    @inlinable public var rawValue: UInt32 { fieldNumber.rawValue << 3 | UInt32(wireType.rawValue) }

    /// Decodes a tag varint.
    /// - Parameters:
    ///   - rawValue: the varint read from the wire.
    ///   - offset: where the tag started, reported in the error.
    /// - Throws: ``WireError/invalidTag(_:at:)`` for field 0 or a value above 32 bits;
    ///   ``WireError/invalidWireType(_:at:)`` for wire type 6 or 7.
    @inlinable public init(rawValue: UInt64, at offset: Int) throws(WireError) {
        guard rawValue <= UInt64(UInt32.max) else { throw .invalidTag(rawValue, at: offset) }
        let raw = UInt32(truncatingIfNeeded: rawValue)
        guard let number = FieldNumber(rawValue: raw >> 3) else { throw .invalidTag(rawValue, at: offset) }
        guard let type = WireType(rawValue: UInt8(truncatingIfNeeded: raw & 7)) else {
            throw .invalidWireType(UInt8(truncatingIfNeeded: raw & 7), at: offset)
        }
        self.init(fieldNumber: number, wireType: type)
    }
}
