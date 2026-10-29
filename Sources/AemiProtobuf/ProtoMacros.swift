/// Makes a struct a protobuf message.
///
/// Every stored property needs `@ProtoField(number)` (and a kind where the Swift type is ambiguous), an explicit type and a
/// default value, because the generated decoder starts from `Self()`. The macro adds:
///
/// - the fast path, `AemiProtoFastEncodable` and `AemiProtoFastDecodable`, which `ProtobufEncoder` and `ProtobufDecoder` call
///   directly;
/// - `Codable`, with integer `CodingKeys` equal to the field numbers, for the generic coders and any other `Codable` code.
///
/// ```swift
/// @ProtoMessage
/// struct User {
///     @ProtoField(1) var id: Int64 = 0
///     @ProtoField(2) var name: String = ""
///     @ProtoField(3, .sint32) var delta: Int32 = 0
///     @ProtoField(4) var tags: [String] = []
///     @ProtoField(5) var address: Address? = nil
/// }
/// ```
///
/// Mapping: a non-optional field holding its default is left out (proto3); an `Optional` field has explicit presence; an
/// array of numbers, `Bool` or enumerations is one packed record; an array of `String`, `Data` or messages is one record per
/// element; any other type is a nested message that also uses `@ProtoMessage`. A non-optional message field whose encoding is empty
/// is left out. Decoding keeps the last occurrence of a scalar field, appends to a repeated one and merges a message field given
/// more than once. Fields the type does not declare, and declared fields with another wire type, are kept in the added
/// `unknownFields` member and written back after the declared fields; `@ProtoMessage(unknownFields: .discard)` skips them and adds
/// no member (ADR-0012). An enumeration whose `init(rawValue:)` cannot fail is open and keeps every number; a raw-value
/// enumeration is closed, and a number with no case goes to the unknown fields (``ProtoEnumeration``). `Int8`, `Int16`, `UInt8`, `UInt16`
/// truncate on decode. Maps, `oneof` and classes are not supported and are diagnosed.
@attached(member, names: named(unknownFields))
@attached(
    extension, conformances: AemiProtoFastEncodable, AemiProtoFastDecodable, Codable, names: named(__aepbEncode),
    named(__aepbDecode), named(__aepbMerge), named(CodingKeys))
public macro ProtoMessage(unknownFields: ProtoUnknownFields = .preserve) =
    #externalMacro(module: "AemiProtobufMacros", type: "ProtoMessageMacro")

/// Gives a property of a ``ProtoMessage()`` struct its protobuf field number, and its kind where the Swift type is ambiguous.
/// - Parameters:
///   - number: the field number, `1...536870911` outside `19000...19999`; unique in the struct.
///   - kind: `.sint32`, `.fixed64` and the other kinds Swift has no distinct type for; `.automatic` infers it from the type.
///   - key: a map's key kind, for a `[Key: Value]` property; `.automatic` infers it from `Key`.
///   - value: a map's value kind; `.automatic` infers it from `Value`.
@attached(peer)
public macro ProtoField(
    _ number: Int, _ kind: ProtoKind = .automatic, key: ProtoKind = .automatic, value: ProtoKind = .automatic
) =
    #externalMacro(module: "AemiProtobufMacros", type: "ProtoFieldMacro")
