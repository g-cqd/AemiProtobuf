public import AemiProtobufCore

/// A `oneof`: an enumeration with one associated value per member, each case marked `@ProtoField(number)`. `@ProtoOneof` writes
/// the conformance; the message holding it marks the property `@ProtoOneof var kind: Kind? = nil` (roadmap 0026).
public protocol AemiProtoOneof: AemiProtoRequiredFields {
    /// Writes the member that is set, even at its default: a member has presence.
    func __aepbEncode(into writer: inout WireWriter) throws(WireError)

    /// Reads the field `tag` opened when it is a member with its wire type, into `value`, and returns `true`; otherwise reads
    /// nothing and returns `false`. The last member wins; a message member given again merges. A closed enumeration member's
    /// number with no case goes to `unknown`.
    static func __aepbDecodeField(
        _ tag: FieldTag, from reader: inout WireReader, into value: inout Self?, unknown: inout UnknownFields
    ) throws(WireError) -> Bool

    /// The members' field lines, for the message's definition (``AemiProtoDefined``).
    static var __aepbOneofDefinition: [String] { get }
    /// The types the members refer to.
    static var __aepbOneofDependencies: [Any.Type] { get }
}

extension AemiProtoOneof {
    /// The members' field lines in the message's definition; `@ProtoOneof` writes them (roadmap 0005).
    public static var __aepbOneofDefinition: [String] { [] }
    /// The types the members refer to.
    public static var __aepbOneofDependencies: [Any.Type] { [] }
}
