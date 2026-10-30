extension DynamicValue {
    /// The order of map keys protoc's deterministic output uses: integers by value, `false` before `true`, strings by their
    /// UTF-8 bytes.
    public static func keyPrecedes(_ a: DynamicValue, _ b: DynamicValue) -> Bool {
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

    /// A map key, or an integer or boolean, as text: decimal, `true` / `false`, a string as it is; empty for anything else.
    public var keyText: String {
        switch self {
            case .int32(let v): String(v)
            case .int64(let v): String(v)
            case .uint32(let v): String(v)
            case .uint64(let v): String(v)
            case .bool(let v): v ? "true" : "false"
            case .string(let v): v
            default: ""
        }
    }
}
