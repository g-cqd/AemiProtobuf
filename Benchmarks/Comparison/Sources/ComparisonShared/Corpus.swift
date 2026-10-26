/// Deterministic data for every workload. Seeds are fixed; nothing here reads a clock or a system generator.
public enum Corpus {
    private static let words = [
        "alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel", "india", "juliet", "kilo", "lima",
        "mike",
        "november", "oscar", "papa", "quebec", "romeo", "sierra", "tango", "uniform", "victor", "whiskey", "xray"
    ]

    /// `count` records with the distribution of AemiJSON's own benchmark model.
    public static func records(_ count: Int) -> [Record] {
        var r = LCG(seed: 0x1234_5678_9abc_def0)
        func word() -> String { words[r.int(words.count)] }
        func sentence(_ n: Int) -> String { (0 ..< n).map { _ in word() }.joined(separator: " ") }
        var out: [Record] = []
        out.reserveCapacity(count)
        for k in 0 ..< count {
            let tags = (0 ..< r.int(5)).map { _ in word() }
            out.append(
                Record(
                    id: k, login: word() + String(k), name: r.int(10) > 2 ? sentence(2) : nil,
                    email: r.int(10) > 3 ? word() + "@" + word() + ".com" : nil, followers: r.int(100_000),
                    following: r.int(2_000), isAdmin: r.int(10) == 0, score: Double(r.int(1_000_000)) / 1000.0,
                    tags: tags,
                    bio: sentence(6), company: r.int(10) > 4 ? word() : nil, publicRepos: r.int(500),
                    location: r.int(10) > 3 ? word() : nil))
        }
        return out
    }

    /// Doubles of the form `n / 997`: most need the full 17 digits in JSON text; always 8 bytes in protobuf.
    public static func fullPrecisionDoubles(_ count: Int) -> [Double] {
        var r = LCG(seed: 0x9e37_79b9_7f4a_7c15)
        return (0 ..< count).map { _ in Double(r.int(1_000_000_000)) / 997.0 }
    }

    /// Doubles with at most three decimals: short in JSON text.
    public static func shortDoubles(_ count: Int) -> [Double] {
        var r = LCG(seed: 0x51ed_2705_91ab_c0de)
        return (0 ..< count).map { _ in Double(r.int(1_000_000)) / 1000.0 }
    }

    /// Integers below 2^31: five bytes at most as varints, ten digits at most as JSON.
    public static func wideIntegers(_ count: Int) -> [Int64] {
        var r = LCG(seed: 0x0ddb_a11c_afe5_eed5)
        return (0 ..< count).map { _ in Int64(r.int(Int(Int32.max))) }
    }

    /// Integers below 128: one byte as varints, up to three digits as JSON.
    public static func smallIntegers(_ count: Int) -> [Int64] {
        var r = LCG(seed: 0x5eed_0f5a_11ab_1e51)
        return (0 ..< count).map { _ in Int64(r.int(128)) }
    }

    /// Strings in four classes: plain ASCII, multi-byte UTF-8, needing JSON escapes, and long.
    public static func strings(_ count: Int, kind: StringKind) -> [String] {
        var r = LCG(seed: 0xfeed_face_cafe_beef)
        return (0 ..< count)
            .map { i in
                switch kind {
                    case .ascii: "user-\(i)-" + words[r.int(words.count)]
                    case .multibyte: "ユーザー\(i)·é·" + words[r.int(words.count)] + "·🙂"
                    case .escaped: "line\n\"quoted\"\t\\path\(i)/" + words[r.int(words.count)]
                    case .long: (0 ..< 40).map { _ in words[r.int(words.count)] }.joined(separator: " ")
                }
            }
    }

    public enum StringKind: String, CaseIterable, Sendable { case ascii, multibyte, escaped, long }
}
