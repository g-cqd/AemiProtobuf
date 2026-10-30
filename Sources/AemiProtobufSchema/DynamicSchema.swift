public import AemiProtobufCore

/// Reads and writes ``DynamicMessage`` values of the message types a descriptor set declares (roadmap 0006).
///
/// Field semantics come from the descriptors and the edition features in force (``ResolvedFeatures``): presence, packing,
/// delimited encoding, closed enumerations, UTF-8 checking, maps and oneofs. Reading and writing are iterative, so nesting is
/// bounded only by `WireLimits.maxDepth`. Extensions are read as unknown fields.
public struct DynamicSchema: Sendable {
    private let types: [String: DynamicMessageType]
    private let enums: [String: EnumDescriptor]

    /// - Complexity: O(messages + fields + enums).
    public init(_ set: FileDescriptorSet) {
        let flat = FlatSchema(set, resolvingFeatures: true)
        let index = SchemaIndex(flat: flat)
        var types: [String: DynamicMessageType] = [:]
        for (name, message) in flat.messages {
            let features = flat.messageFeatures[name] ?? .proto2
            let fields = message.fields.map {
                DynamicField($0, in: name, features: features, schema: flat, index: index)
            }
            types[name] = DynamicMessageType(name: name, descriptor: message, fields: fields)
        }
        self.types = types
        enums = flat.enums
    }

    /// The message type with this fully qualified name (no leading dot).
    public func messageType(named name: String) -> DynamicMessageType? { types[name] }

    /// The enumeration with this fully qualified name (no leading dot).
    public func enumeration(named name: String) -> EnumDescriptor? { enums[name] }

    /// Reads `bytes` as a message of the type `typeName` names. Repeated occurrences of a field merge as protobuf specifies: a
    /// scalar's last value wins, repeated fields append, messages merge, and setting a oneof member clears the others.
    /// - Throws: ``DynamicMessageError/unknownMessageType(_:)``, or ``DynamicMessageError/wire(_:)`` for malformed input, a
    ///   `string` that must be UTF-8 and is not, nesting past `limits.maxDepth`, or a missing required field.
    public func decode(
        _ bytes: [UInt8], as typeName: String, limits: WireLimits = .default
    ) throws(DynamicMessageError) -> DynamicMessage {
        guard let type = types[typeName] else { throw .unknownMessageType(typeName) }
        var decoder = DynamicDecoder(schema: self, bytes: bytes, limits: limits, root: type)
        do throws(WireError) {
            return try decoder.run()
        } catch {
            throw .wire(error)
        }
    }

    /// Writes `message` with its fields in number order, map entries by key, and its unknown fields last: the bytes protoc
    /// writes with deterministic output. An implicit-presence field at its default is left out.
    /// - Throws: ``DynamicMessageError/unknownMessageType(_:)``, ``DynamicMessageError/unknownField(message:number:)``,
    ///   ``DynamicMessageError/typeMismatch(message:field:)``, or ``DynamicMessageError/wire(_:)`` past `limits`.
    public func encode(_ message: DynamicMessage, limits: WireLimits = .default) throws(DynamicMessageError) -> [UInt8]
    {
        var encoder = DynamicEncoder(schema: self, limits: limits)
        return try encoder.run(message)
    }

    /// The value an absent field reads as: zero, empty, `false`, an enumeration's first value, an empty message.
    func defaultValue(of field: FieldDescriptor, typeName: String?) -> DynamicValue {
        DynamicValue.zero(
            of: field.type, typeName: typeName, firstEnumValue: typeName.flatMap { enums[$0]?.values.first?.number })
    }
}
