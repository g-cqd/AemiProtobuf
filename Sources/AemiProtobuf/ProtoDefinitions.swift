/// Assembles definitions into a `.proto` file (roadmap 0005).
public enum ProtoDefinitions {
    public static func file(for types: [Any.Type], package: String = "") throws(ProtoDefinitionError) -> String {
        throw ProtoDefinitionError.undefined("")
    }
}
