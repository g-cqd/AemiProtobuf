/// What checking one message found, and the nested messages it left to check.
struct MessageCheck {
    var errors: [WireValidationError] = []
    var nested: [NestedPayload] = []
    /// The finding budget ran out.
    var stopped = false
}
