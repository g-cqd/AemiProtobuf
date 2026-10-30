/// Why a `.proto` file did not compile: where, and what protoc would say.
public struct ProtoCompileError: Error, Sendable, Equatable, CustomStringConvertible {
    public let file: String
    /// 1-based; 0 when the error has no single place (a missing import, a cycle).
    public let line: Int
    public let column: Int
    public let message: String

    public init(file: String, line: Int = 0, column: Int = 0, message: String) {
        self.file = file
        self.line = line
        self.column = column
        self.message = message
    }

    public var description: String { "\(file):\(line):\(column): \(message)" }
}
