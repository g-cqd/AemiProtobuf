public import AemiProtobufCore

/// Checks wire bytes against a descriptor: wire types, packed framing, UTF-8, required fields, and, given a descriptor set,
/// every nested message.
///
/// Two entry points. ``validate(bytes:against:)-(_,MessageDescriptor)`` checks one message and skips nested payloads.
/// ``validate(bytes:against:in:)`` resolves nested types in a ``FileDescriptorSet`` and checks each nested message, reporting
/// where in the message each finding is.
public struct WireValidator: Sendable {
    /// Whether undeclared field numbers are accepted.
    public var allowUnknownFields: Bool
    /// Bounds applied by the wire reader and to the depth of nested messages.
    public var limits: WireLimits
    /// Maximum findings before validation stops, excluding the final limit marker.
    public let maxFindings: Int

    /// Creates a validator. Nonpositive finding limits are clamped to one.
    public init(allowUnknownFields: Bool = true, limits: WireLimits = .default, maxFindings: Int = 256) {
        self.allowUnknownFields = allowUnknownFields
        self.limits = limits
        self.maxFindings = max(1, maxFindings)
    }

    /// Checks one message without throwing or trapping on malformed wire values or duplicate field numbers. Nested message
    /// payloads are skipped; use ``validate(bytes:against:in:)`` to check them.
    ///
    /// Returns at most `maxFindings` findings plus a limit marker when checking stops early. Corruption stops traversal of the
    /// message, and required-field checks run only after a complete traversal.
    /// - Complexity: O(bytes + descriptor fields) time, O(descriptor fields + maxFindings) space, plus the largest packed payload.
    public func validate(bytes: [UInt8], against descriptor: MessageDescriptor) -> [WireValidationError] {
        let check = checkMessage(
            bytes, 0 ..< bytes.count, descriptor, depth: 0, budget: maxFindings, collectNested: false)
        return check.stopped ? check.errors + [.findingLimitReached] : check.errors
    }

    static func isPackable(_ type: WireType) -> Bool {
        type == .varint || type == .fixed32 || type == .fixed64
    }

    static func expectedWireType(for type: FieldType) -> WireType {
        switch type {
            case .int32, .int64, .uint32, .uint64, .sint32, .sint64, .bool, .enum: .varint
            case .fixed64, .sfixed64, .double: .fixed64
            case .string, .bytes, .message: .lengthDelimited
            case .fixed32, .sfixed32, .float: .fixed32
            case .group: .startGroup
        }
    }
}
