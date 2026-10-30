/// Naming and declaration rules for a descriptor set (roadmap 0008).
public struct SchemaLinter: Sendable {
    public init() {}

    public func lint(_ set: FileDescriptorSet) -> [LintFinding] { [] }
}
