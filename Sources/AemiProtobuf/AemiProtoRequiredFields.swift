/// A message that can say which proto2 `required` field it lacks (roadmap 0027). The coders ask after a whole decode, so a field
/// supplied by a later occurrence of its message counts, and before an encode, as C++ does.
public protocol AemiProtoRequiredFields {
    /// The path to the first absent `required` field, outermost first (`["child", "many[1]", "a"]`), or `nil` when none is
    /// absent. Allocates nothing when none is.
    func __aepbMissingRequired() -> [String]?
}

extension AemiProtoRequiredFields {
    /// A type with no `required` field and no message that could hold one.
    @inlinable
    public func __aepbMissingRequired() -> [String]? { nil }
}

// The containers' walks are inlinable, so they specialize where they are called: unspecialized, the walk copied each element
// of a large message into a heap buffer (two allocations a message on the allocation gate).
extension Array: AemiProtoRequiredFields where Element: AemiProtoRequiredFields {
    @inlinable
    public func __aepbMissingRequired() -> [String]? {
        for index in indices {
            if let path = self[index].__aepbMissingRequired() { return ["[\(index)]"] + path }
        }
        return nil
    }
}

extension Optional: AemiProtoRequiredFields where Wrapped: AemiProtoRequiredFields {
    @inlinable
    public func __aepbMissingRequired() -> [String]? { self?.__aepbMissingRequired() }
}

extension Dictionary: AemiProtoRequiredFields where Value: AemiProtoRequiredFields {
    @inlinable
    public func __aepbMissingRequired() -> [String]? {
        for index in indices {
            if let path = self[index].value.__aepbMissingRequired() { return ["[\(self[index].key)]"] + path }
        }
        return nil
    }
}

extension Indirect: AemiProtoRequiredFields where Value: AemiProtoRequiredFields {
    @inlinable
    public func __aepbMissingRequired() -> [String]? { wrappedValue.__aepbMissingRequired() }
}

extension WireError {
    /// The error for a message whose `__aepbMissingRequired()` found `path`.
    static func missingRequired(_ path: [String]) -> WireError {
        var text = ""
        for component in path {
            if !text.isEmpty, !component.hasPrefix("[") { text += "." }
            text += component
        }
        return .missingRequired(path: text)
    }
}
