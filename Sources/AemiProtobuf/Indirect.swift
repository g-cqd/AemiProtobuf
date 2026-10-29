/// Stores a field out of line, so a message can hold itself (roadmap 0024): `@ProtoField(2) @Indirect var child: Node? = nil`.
///
/// A value: the storage is shared between copies and copied on the first write to a shared one.
@propertyWrapper
public struct Indirect<Value> {
    private final class Box {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    private var box: Box

    public init(wrappedValue: Value) {
        box = Box(wrappedValue)
    }

    public var wrappedValue: Value {
        get { box.value }
        _modify {
            if !isKnownUniquelyReferenced(&box) { box = Box(box.value) }
            yield &box.value
        }
    }
}

extension Indirect: Equatable where Value: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.wrappedValue == rhs.wrappedValue }
}

extension Indirect: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(wrappedValue) }
}

// The box is written only when no other copy shares it, so a shared box is never written.
extension Indirect: @unchecked Sendable where Value: Sendable {}

extension Indirect: Encodable where Value: Encodable {
    /// Encodes the wrapped value in its place, as if there were no wrapper.
    public func encode(to encoder: any Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension Indirect: Decodable where Value: Decodable {
    public init(from decoder: any Decoder) throws {
        self.init(wrappedValue: try Value(from: decoder))
    }
}

extension KeyedDecodingContainer {
    /// An absent optional `@Indirect` field is `nil`, as an absent `Optional` property is.
    public func decode<Wrapped: Decodable>(_ type: Indirect<Wrapped?>.Type, forKey key: Key) throws -> Indirect<
        Wrapped?
    > {
        // Another overload (`Wrapped`, not `Indirect<Wrapped?>`), called through a copy so the recursion scan, which matches by
        // name and label, does not take it for this function.
        let container = self
        return Indirect(wrappedValue: try container.decodeIfPresent(Wrapped.self, forKey: key))
    }
}

extension KeyedEncodingContainer {
    /// A `nil` optional `@Indirect` field is left out, as a `nil` `Optional` property is.
    public mutating func encode<Wrapped: Encodable>(_ value: Indirect<Wrapped?>, forKey key: Key) throws {
        try encodeIfPresent(value.wrappedValue, forKey: key)
    }
}
