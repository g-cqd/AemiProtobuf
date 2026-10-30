public import AemiProtobufCore

/// Reads and writes ``DynamicMessage`` values of the message types a descriptor set declares (roadmap 0006).
public struct DynamicSchema: Sendable {
    public init(_ set: FileDescriptorSet) {}

    public func decode(
        _ bytes: [UInt8], as typeName: String, limits: WireLimits = .default
    ) throws(DynamicMessageError) -> DynamicMessage {
        throw .unknownMessageType(typeName)
    }

    public func encode(_ message: DynamicMessage, limits: WireLimits = .default) throws(DynamicMessageError) -> [UInt8]
    {
        throw .unknownMessageType(message.typeName)
    }
}
