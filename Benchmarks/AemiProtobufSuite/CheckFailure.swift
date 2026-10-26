/// Why a benchmark's setup check failed.
struct CheckFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) { self.description = description }
}
