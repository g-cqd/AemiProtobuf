public struct ProtoParseError: Error, Sendable, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
}
