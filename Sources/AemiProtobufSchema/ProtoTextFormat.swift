/// Protobuf's text format over dynamic messages (roadmap 0011). Reading accepts every form the format allows: `#` comments,
/// `:` optional before a message, `{ }` or `< >`, lists, `,` or `;` between fields, integers in any base, `inf` / `nan`, an
/// `f` suffix, adjacent strings with C escapes, group fields by their type name, `[extension.name]`, and an `Any` written as
/// `[type.googleapis.com/pkg.Type] { … }`. A non-repeated field given twice, two members of a oneof, a closed enumeration's
/// unknown number, and a missing required field are refused, as C++ refuses them. Writing puts one top-level field per line.
public struct ProtoTextFormat: Sendable {
    public let schema: DynamicSchema
    /// The deepest nesting read.
    public var maxDepth = 100

    public init(schema: DynamicSchema) { self.schema = schema }

    public func decode(_ text: String, as typeName: String) throws(ProtoTextFormatError) -> DynamicMessage {
        guard let type = schema.messageType(named: typeName) else {
            throw ProtoTextFormatError(line: 0, column: 0, message: "unknown message type \(typeName)")
        }
        let message: DynamicMessage
        do throws(ProtoCompileError) {
            let tokens = try ProtoTokenizer.tokens(text, file: "", hashComments: true)
            var parser = ProtoTextParser(
                schema: schema, resolveExtension: { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 },
                stream: ProtoTokenStream(tokens, file: ""), maxDepth: maxDepth)
            message = try parser.parse(as: type)
        } catch {
            throw ProtoTextFormatError(line: error.line, column: error.column, message: error.message)
        }
        // A round trip through the binary form checks required fields and drops implicit defaults written out.
        do throws(DynamicMessageError) {
            return try schema.decode(try schema.encode(message), as: typeName)
        } catch {
            throw ProtoTextFormatError(line: 0, column: 0, message: "\(error)")
        }
    }

    /// The message in text format, one top-level field per line; unknown fields by number when `printUnknownFields`.
    public func encode(_ message: DynamicMessage, printUnknownFields: Bool = false) -> String {
        ProtoTextPrinter(schema: schema, printUnknownFields: printUnknownFields).printFields(message)
    }
}
