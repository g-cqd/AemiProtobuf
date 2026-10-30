public import AemiProtobufSchema

/// Why a message could not be read from JSON or written as JSON.
public enum ProtoJSONError: Error, Sendable, Equatable {
    /// The text is not JSON.
    case syntax(String)
    /// The JSON is well formed but is not a valid form of the message: the reason, and where (a field path).
    case invalid(String, path: String)
    /// A member the message type does not declare.
    case unknownField(message: String, name: String)
    /// A message type, named by the caller or an `Any`, that the descriptor set lacks.
    case unknownType(String)
    /// Reading or writing the binary form (an `Any`'s payload, or a transcoding).
    case dynamic(DynamicMessageError)
}
