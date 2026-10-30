/// Why a constant does not fit a field's type; the caller adds where.
struct ProtoValueError: Error {
    let message: String

    init(_ message: String) { self.message = message }
}
