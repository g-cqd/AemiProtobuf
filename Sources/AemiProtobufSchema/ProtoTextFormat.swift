/// Protobuf's text format over dynamic messages (roadmap 0011).
public struct ProtoTextFormat: Sendable {
    public let schema: DynamicSchema

    public init(schema: DynamicSchema) { self.schema = schema }

    public func decode(_ text: String, as typeName: String) throws(ProtoTextFormatError) -> DynamicMessage {
        throw ProtoTextFormatError(line: 0, column: 0, message: "not implemented")
    }

    public func encode(_ message: DynamicMessage, printUnknownFields: Bool = false) -> String { "" }
}
