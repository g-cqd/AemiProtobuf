/// An enumeration as parsed: its descriptor, the index of the message it is nested in, and its options and its values'.
struct ParsedEnum: Sendable {
    var descriptor: EnumDescriptor
    let parent: Int?
    let fullName: String
    var options: [ParsedOption] = []
    var valueOptions: [[ParsedOption]] = []
    let line: Int
    let column: Int
}
