/// A field number: 1 through 2^29-1. A value outside that range cannot be built, so no tag can carry one.
///
/// The range 19,000 through 19,999 is reserved for the protobuf implementation in `.proto` files, but it is legal on the
/// wire, so this type accepts it.
public struct FieldNumber: RawRepresentable, Hashable, Comparable, Sendable, ExpressibleByIntegerLiteral {
    public static let maximum: UInt32 = 536_870_911

    public let rawValue: UInt32

    /// - Returns: `nil` when `rawValue` is 0 or above ``maximum``.
    @inlinable public init?(rawValue: UInt32) {
        guard rawValue >= 1, rawValue <= Self.maximum else { return nil }
        self.rawValue = rawValue
    }

    /// For literals in source and in macro output.
    /// - Precondition: the literal is in `1...536_870_911`. A literal outside it is a programming error.
    @inlinable public init(integerLiteral value: UInt32) {
        guard let number = Self(rawValue: value) else { preconditionFailure("field number \(value) is out of range") }
        self = number
    }

    @inlinable public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
