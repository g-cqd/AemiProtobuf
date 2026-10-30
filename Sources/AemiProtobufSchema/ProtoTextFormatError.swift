/// Why text did not read as a message: where, and why.
public struct ProtoTextFormatError: Error, Sendable, Equatable, CustomStringConvertible {
    public let line: Int
    public let column: Int
    public let message: String

    public var description: String { "\(line):\(column): \(message)" }
}
