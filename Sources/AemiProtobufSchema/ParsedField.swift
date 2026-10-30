/// A field or extension as parsed: its descriptor so far, with what is resolved or interpreted later beside it.
struct ParsedField: Sendable {
    var descriptor: FieldDescriptor
    /// The type is a name still to resolve (a message, an enumeration, or a group's message).
    var namedType: Bool
    var options: [ParsedOption] = []
    var defaultValue: ProtoOptionValue?
    /// For an extension: the message index it was declared in, or `nil` at file level.
    var scope: Int?
    let line: Int
    let column: Int
}
