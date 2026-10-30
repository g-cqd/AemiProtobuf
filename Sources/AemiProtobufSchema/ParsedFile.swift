/// A `.proto` file as parsed, before names are resolved and options interpreted. Messages and enumerations are flat, each with
/// the index of the message it is nested in, in the order they were declared, so every later pass is a loop.
struct ParsedFile: Sendable {
    var name: String
    /// `""` for proto2 written without `syntax` (protoc writes none), `"proto2"`, `"proto3"` or `"editions"`.
    var syntax = ""
    var edition: Int32?
    var package = ""
    var dependencies: [String] = []
    var publicDependencies: [Int32] = []
    var weakDependencies: [Int32] = []
    var options: [ParsedOption] = []
    /// The file's options once interpreted.
    var optionBytes: [UInt8]?
    var messages: [ParsedMessage] = []
    var enums: [ParsedEnum] = []
    var services: [ParsedService] = []
    var extensions: [ParsedField] = []

    /// The syntax that governs semantics: proto2 when none was written.
    var resolvedSyntax: String { syntax.isEmpty ? "proto2" : syntax }

    /// The scope a declaration inside message `index` (or at file level) names things from.
    func scope(of index: Int?) -> String { index.map { messages[$0].fullName } ?? package }
}
