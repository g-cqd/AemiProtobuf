/// Stores a field out of line, so a message can hold itself (roadmap 0024).
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
        set { box.value = newValue }
    }
}

extension Indirect: Equatable where Value: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.wrappedValue == rhs.wrappedValue }
}

extension Indirect: @unchecked Sendable where Value: Sendable {}

extension Indirect: Encodable where Value: Encodable {
    public func encode(to encoder: any Encoder) throws {}
}

extension Indirect: Decodable where Value: Decodable {
    public init(from decoder: any Decoder) throws {
        self.init(wrappedValue: try decoder.singleValueContainer().decode(Value.self))
    }
}
