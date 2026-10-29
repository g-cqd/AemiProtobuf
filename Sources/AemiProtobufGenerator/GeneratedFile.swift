/// One Swift file the generator wrote: its path, relative to the output directory, and its text.
public struct GeneratedFile: Sendable, Equatable {
    public var name: String
    public var content: String

    public init(name: String, content: String) {
        self.name = name
        self.content = content
    }
}
