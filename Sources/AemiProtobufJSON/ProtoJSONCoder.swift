public import AemiProtobufSchema

/// Reads and writes dynamic messages in protobuf's JSON form (roadmap 0010).
public struct ProtoJSONCoder: Sendable {
    public struct Options: Sendable {
        public var ignoreUnknownFields: Bool
        public var emitDefaultValues: Bool
        public var useProtoFieldNames: Bool
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

    public func decode(json: [UInt8], as typeName: String) throws(ProtoJSONError) -> DynamicMessage {
        throw .unknownType(typeName)
    }

    public func encode(_ message: DynamicMessage) throws(ProtoJSONError) -> [UInt8] {
        throw .unknownType(message.typeName)
    }
}
