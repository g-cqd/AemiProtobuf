/// What the generated code looks like: `visibility=public` for a library's own types, `unknown_fields=discard` for a format
/// only its writer reads (protoc's `--aemi_opt`, comma-separated `key=value`).
public struct GeneratorOptions: Sendable, Equatable {
    public enum Visibility: String, Sendable { case `internal`, `public` }

    public var visibility: Visibility = .internal
    public var discardsUnknownFields = false

    public init() {}

    /// Options from protoc's parameter string; an unknown key is an error, so a misspelling does not pass silently.
    public init(parameter: String) throws(GeneratorError) {
        for pair in parameter.split(separator: ",") where !pair.isEmpty {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            switch (parts.first, parts.count == 2 ? parts[1] : nil) {
                case ("visibility", let value?):
                    guard let visibility = Visibility(rawValue: value) else {
                        throw .badOption("visibility is internal or public, not \(value)")
                    }
                    self.visibility = visibility
                case ("unknown_fields", "preserve"?): discardsUnknownFields = false
                case ("unknown_fields", "discard"?): discardsUnknownFields = true
                default: throw .badOption("unknown option \(pair)")
            }
        }
    }
}
