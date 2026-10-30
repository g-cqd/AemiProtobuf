/// One rule a schema breaks: the rule's name (buf's, where buf has the rule), the declaration's name, and why.
public struct LintFinding: Sendable, Equatable {
    public var rule: String
    public var name: String
    public var message: String

    public init(rule: String, name: String, message: String) {
        self.rule = rule
        self.name = name
        self.message = message
    }
}
