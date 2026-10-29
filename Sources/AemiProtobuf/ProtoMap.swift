/// The order the generated code writes a map in: by key, as C++ writes with deterministic serialization, so equal maps give equal
/// bytes. Numbers by value, strings by their UTF-8 bytes (C++'s order, which normalization cannot change), `false` before `true`.
public enum ProtoMap {
    @inlinable
    public static func sorted<Key: Comparable, Value>(_ map: [Key: Value]) -> [(key: Key, value: Value)] {
        map.sorted { $0.key < $1.key }
    }

    @inlinable
    public static func sorted<Value>(_ map: [String: Value]) -> [(key: String, value: Value)] {
        map.sorted { $0.key.utf8.lexicographicallyPrecedes($1.key.utf8) }
    }

    @inlinable
    public static func sorted<Value>(_ map: [Bool: Value]) -> [(key: Bool, value: Value)] {
        [false, true].compactMap { key in map[key].map { (key, $0) } }
    }
}
