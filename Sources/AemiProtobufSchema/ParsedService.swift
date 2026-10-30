/// A service as parsed: its descriptor, with its options and its methods' beside it.
struct ParsedService: Sendable {
    var descriptor: ServiceDescriptor
    let fullName: String
    var options: [ParsedOption] = []
    var methodOptions: [[ParsedOption]] = []
    /// The methods written with a `{ … }` body, which protoc gives options even when the body holds none.
    var methodBodies: Set<Int> = []
    let line: Int
    let column: Int
}
