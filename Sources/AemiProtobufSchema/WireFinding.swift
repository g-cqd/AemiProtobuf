/// One problem found in a message, with where it is.
public struct WireFinding: Sendable, Equatable {
    /// The fields leading to the message, from the root: `""` for the root, `users[2].profile` for the profile of the third
    /// element of `users`. Repeated message fields carry the element's index.
    public var path: String
    public var error: WireValidationError

    public init(path: String, error: WireValidationError) {
        self.path = path
        self.error = error
    }
}
