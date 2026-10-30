extension DynamicValue {
    /// The order of map keys protoc's deterministic output uses: integers by value, `false` before `true`, strings by their
    /// UTF-8 bytes.
    static func keyPrecedes(_ a: DynamicValue, _ b: DynamicValue) -> Bool {
        switch (a, b) {
            case (.int32(let x), .int32(let y)): x < y
            case (.int64(let x), .int64(let y)): x < y
            case (.uint32(let x), .uint32(let y)): x < y
            case (.uint64(let x), .uint64(let y)): x < y
            case (.bool(let x), .bool(let y)): !x && y
            case (.string(let x), .string(let y)): x.utf8.lexicographicallyPrecedes(y.utf8)
            default: false
        }
    }
}
