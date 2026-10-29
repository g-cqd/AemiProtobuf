/// Why a file could not be generated.
public enum GeneratorError: Error, Sendable, Equatable {
    case badOption(String)
    /// A field refers to a type the descriptor set does not contain.
    case unknownType(String)
    /// protoc asked for a file the request does not describe.
    case unknownFile(String)
}
