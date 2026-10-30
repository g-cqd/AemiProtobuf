import AemiJSONCore
public import AemiProtobufSchema

/// Reads and writes dynamic messages in protobuf's JSON form, the proto3 JSON mapping (roadmap 0010;
/// protobuf.dev/programming-guides/json).
///
/// Fields are written by their JSON names in number order, implicit-presence fields at their defaults left out; 64-bit integers
/// as strings, `bytes` in base64, enumerations by name, maps as objects; Timestamp, Duration, FieldMask, the wrappers, Struct,
/// Value, ListValue, Empty and Any in their own forms. Reading accepts JSON or declared names, integers as numbers or strings,
/// and base64 in either alphabet. Both directions are iterative, nesting bounded by ``Options/maxDepth``.
///
/// A `@ProtoMessage` or generated type goes through its binary form, so this module needs neither the macros nor Foundation:
///
/// ```swift
/// let json = try coder.json(fromBinary: try ProtobufEncoder().encodeToBytes(value), as: "pkg.Message")
/// let value = try ProtobufDecoder().decode(Message.self, fromBytes: try coder.binary(fromJSON: json, as: "pkg.Message"))
/// ```
public struct ProtoJSONCoder: Sendable {
    public struct Options: Sendable {
        /// Skip members the message type does not declare, and enumeration names it lacks, instead of refusing them.
        public var ignoreUnknownFields: Bool
        /// Write fields without presence even at their defaults (`0`, `""`, `[]`, `{}`).
        public var emitDefaultValues: Bool
        /// Write the declared field names instead of the JSON names.
        public var useProtoFieldNames: Bool
        /// The deepest nesting of messages read.
        public var maxDepth: Int

        public init(
            ignoreUnknownFields: Bool = false, emitDefaultValues: Bool = false, useProtoFieldNames: Bool = false,
            maxDepth: Int = 100
        ) {
            self.ignoreUnknownFields = ignoreUnknownFields
            self.emitDefaultValues = emitDefaultValues
            self.useProtoFieldNames = useProtoFieldNames
            self.maxDepth = maxDepth
        }
    }

    public let schema: DynamicSchema
    public let options: Options

    public init(schema: DynamicSchema, options: Options = Options()) {
        self.schema = schema
        self.options = options
    }

    /// Reads `json` (UTF-8) as a message of the type `typeName` names.
    public func decode(json: [UInt8], as typeName: String) throws(ProtoJSONError) -> DynamicMessage {
        guard let type = schema.messageType(named: typeName) else { throw .unknownType(typeName) }
        let document: JSONDocument
        do throws(JSONError) {
            document = try AemiJSON.parse(json, options: JSONParseOptions(maxDepth: options.maxDepth + 64))
        } catch {
            throw .syntax("\(error)")
        }
        var parser = ProtoJSONParser(schema: schema, options: options)
        return try parser.run(document.root, as: type)
    }

    /// Writes `message` as JSON text (UTF-8, no white space).
    public func encode(_ message: DynamicMessage) throws(ProtoJSONError) -> [UInt8] {
        var printer = ProtoJSONPrinter(schema: schema, options: options)
        return try printer.run(message)
    }

    /// JSON to the binary encoding.
    public func binary(fromJSON json: [UInt8], as typeName: String) throws(ProtoJSONError) -> [UInt8] {
        let message = try decode(json: json, as: typeName)
        do throws(DynamicMessageError) {
            return try schema.encode(message)
        } catch {
            throw .dynamic(error)
        }
    }

    /// The binary encoding to JSON.
    public func json(fromBinary bytes: [UInt8], as typeName: String) throws(ProtoJSONError) -> [UInt8] {
        let message: DynamicMessage
        do throws(DynamicMessageError) {
            message = try schema.decode(bytes, as: typeName)
        } catch {
            throw .dynamic(error)
        }
        return try encode(message)
    }
}
