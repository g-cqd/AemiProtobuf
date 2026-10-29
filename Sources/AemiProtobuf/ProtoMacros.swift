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
/// truncate on decode. A `[Key: Value]` is a map: repeated entry messages, key 1 and value 2, both always written, entries in
/// ``ProtoMap`` order so equal maps give equal bytes; `@ProtoField(n, key: .sint64, value: .enumeration)` gives kinds Swift cannot
/// tell. A `oneof` is a ``ProtoOneof()`` enumeration in a ``ProtoOneofField()`` property. Classes are not supported and are
/// diagnosed; a message that holds itself does so through ``Indirect``.
@attached(member, names: named(unknownFields))
@attached(
    extension, conformances: AemiProtoFastEncodable, AemiProtoFastDecodable, Codable, names: named(__aepbEncode),
    named(__aepbDecode), named(__aepbMerge), named(__aepbMissingRequired), named(CodingKeys))
public macro ProtoMessage(unknownFields: ProtoUnknownFields = .preserve) =
    #externalMacro(module: "AemiProtobufMacros", type: "ProtoMessageMacro")

/// Gives a property of a ``ProtoMessage()`` struct its protobuf field number, and its kind where the Swift type is ambiguous.
/// - Parameters:
///   - number: the field number, `1...536870911` outside `19000...19999`; unique in the struct.
///   - kind: `.sint32`, `.fixed64` and the other kinds Swift has no distinct type for; `.automatic` infers it from the type.
///   - key: a map's key kind, for a `[Key: Value]` property; `.automatic` infers it from `Key`.
///   - value: a map's value kind; `.automatic` infers it from `Value`.
///   - required: a proto2 `required` field, on an `Optional` property: the coders refuse a message without it.
@attached(peer)
public macro ProtoField(
    _ number: Int, _ kind: ProtoKind = .automatic, key: ProtoKind = .automatic, value: ProtoKind = .automatic,
    required: Bool = false
) =
    #externalMacro(module: "AemiProtobufMacros", type: "ProtoFieldMacro")

/// Makes an enumeration a protobuf `oneof`.
///
/// Every case has one associated value and `@ProtoField(number)` (with a kind where the Swift type is ambiguous), as a message
/// field would; the macro adds ``AemiProtoOneof`` and `Codable`. The message holds it in an optional property marked
/// ``ProtoOneofField()``, with no number of its own.
///
/// ```swift
/// @ProtoOneof
/// enum Kind {
///     @ProtoField(1) case circle(Int32)
///     @ProtoField(2) case leaf(Leaf)
/// }
/// ```
@attached(
    extension, conformances: AemiProtoOneof, Codable, names: named(__aepbEncode), named(__aepbDecodeField),
    named(__aepbMissingRequired))
public macro ProtoOneof() = #externalMacro(module: "AemiProtobufMacros", type: "ProtoOneofMacro")

/// Marks the property of a ``ProtoMessage(unknownFields:)`` that holds a ``ProtoOneof()`` enumeration:
/// `@ProtoOneofField var kind: Kind? = nil`. A marker: `@ProtoMessage` reads it.
@attached(peer)
public macro ProtoOneofField() = #externalMacro(module: "AemiProtobufMacros", type: "ProtoFieldMacro")
