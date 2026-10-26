/// How many values a field holds.
enum ProtoFieldShape {
    /// Implicit presence: a default value is left out.
    case single
    /// Explicit presence: a set value is always written.
    case optional
    /// Zero or more values.
    case repeated
}
