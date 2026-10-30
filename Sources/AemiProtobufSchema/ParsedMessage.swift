/// A message as parsed, flat: its descriptor without fields or nested declarations, the index of the message it is nested in,
/// and its fields and options beside it.
struct ParsedMessage: Sendable {
    var descriptor: MessageDescriptor
    let parent: Int?
    let fullName: String
    var fields: [ParsedField] = []
    var options: [ParsedOption] = []
    /// Options of each extension range, in order.
    var rangeOptions: [[ParsedOption]] = []
    /// Extension ranges written `to max`, finished once the message's options are known (a message set's max is larger).
    var rangesToMax: Set<Int> = []
    var oneofOptions: [[ParsedOption]] = []
    let line: Int
    let column: Int
}
