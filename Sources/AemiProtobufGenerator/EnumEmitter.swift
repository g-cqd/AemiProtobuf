import AemiProtobufSchema

/// An enumeration: closed ones as raw-value enumerations, open ones as `RawRepresentable` with an `unrecognized` case, so a
/// number with no case survives (roadmap 0023).
enum EnumEmitter {
    /// `name`: the Swift name it is declared with (a top-level one carries its package prefix).
    static func emit(_ enumeration: EnumDescriptor, open: Bool, access: String, name: String? = nil) -> [String] {
        var cases: [(name: String, number: Int32)] = []
        var aliases: [(name: String, target: String)] = []
        var used: Set<String> = ["unrecognized"]
        var byNumber: [Int32: String] = [:]
        for value in enumeration.values {
            var name = SwiftNaming.enumCase(value.name, enumName: enumeration.name)
            while used.contains(name) { name += "_" }
            used.insert(name)
            if let target = byNumber[value.number] {
                aliases.append((name, target))
            } else {
                byNumber[value.number] = name
                cases.append((name, value.number))
            }
        }
        let name = name ?? enumeration.name
        let aliasLines = aliases.map { "\(access)static let \($0.name): \(name) = .\($0.target)" }
        guard open else {
            return ["\(access)enum \(name): Int32, Codable, Sendable, CaseIterable {"]
                + cases.map { "case \($0.name) = \($0.number)" } + aliasLines + ["}"]
        }
        var lines = ["\(access)enum \(name): RawRepresentable, Hashable, Codable, Sendable {"]
        lines += cases.map { "case \($0.name)" } + ["case unrecognized(Int32)"] + aliasLines
        lines += ["", "\(access)init(rawValue: Int32) {", "switch rawValue {"]
        lines += cases.map { "case \($0.number): self = .\($0.name)" }
        lines += [
            "default: self = .unrecognized(rawValue)", "}", "}", "", "\(access)var rawValue: Int32 {", "switch self {"
        ]
        lines += cases.map { "case .\($0.name): \($0.number)" }
        lines += ["case .unrecognized(let value): value", "}", "}", ""]
        lines += [
            "\(access)init(from decoder: any Decoder) throws {",
            "self.init(rawValue: try decoder.singleValueContainer().decode(Int32.self))", "}", "",
            "\(access)func encode(to encoder: any Encoder) throws {", "var container = encoder.singleValueContainer()",
            "try container.encode(rawValue)", "}", "}"
        ]
        return lines
    }
}
