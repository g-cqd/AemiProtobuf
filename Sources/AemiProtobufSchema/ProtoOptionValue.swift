/// A constant as written in an option or a `default`: interpreted later against the type of what it sets.
enum ProtoOptionValue: Equatable, Sendable {
    /// `true`, an enumeration value, `inf`, `nan`; negative when written with a `-`.
    case identifier(String, negative: Bool)
    /// The digits as written (`15`, `0x1F`, `017`), and the sign.
    case integer(String, negative: Bool)
    case float(String, negative: Bool)
    /// One or more adjacent string literals, concatenated, escapes decoded.
    case string([UInt8])
    /// A message literal: the text-format tokens between its braces.
    case aggregate([ProtoToken])
}
