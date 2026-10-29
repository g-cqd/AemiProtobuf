/// The protobuf scalar or message type a field is written as. The names are the cases of the public `ProtoKind` the
/// attribute is spelled with; the macro reads them from syntax, so the two lists must match.
enum ProtoKind: String, CaseIterable {
    case int32, int64, uint32, uint64, sint32, sint64, fixed32, fixed64, sfixed32, sfixed64
    case bool, float, double, string, bytes, message, enumeration, group

    /// The Swift spellings a field of this kind may have.
    var swiftTypes: Set<String>? {
        switch self {
            case .int32: ["Int32", "Int16", "Int8"]
            case .int64, .sint64, .sfixed64: ["Int64", "Int"]
            case .uint32: ["UInt32", "UInt16", "UInt8"]
            case .uint64, .fixed64: ["UInt64", "UInt"]
            case .sint32, .sfixed32: ["Int32"]
            case .fixed32: ["UInt32"]
            case .bool: ["Bool"]
            case .float: ["Float"]
            case .double: ["Double"]
            case .string: ["String"]
            case .bytes: ["Data", "[UInt8]"]
            case .message, .enumeration, .group: nil
        }
    }

    /// The kind a Swift type is written as when the attribute names none.
    static func inferred(for type: String) -> ProtoKind {
        switch type {
            case "Int", "Int64": .int64
            case "Int32", "Int16", "Int8": .int32
            case "UInt", "UInt64": .uint64
            case "UInt32", "UInt16", "UInt8": .uint32
            case "Bool": .bool
            case "Float": .float
            case "Double": .double
            case "String": .string
            case "Data", "[UInt8]": .bytes
            default: .message
        }
    }

    /// Whether a repeated field of this kind is one packed record (proto3) rather than one record per element.
    var isPackable: Bool {
        switch self {
            case .string, .bytes, .message, .group: false
            default: true
        }
    }

    var wireType: String {
        switch self {
            case .fixed32, .sfixed32, .float: ".fixed32"
            case .fixed64, .sfixed64, .double: ".fixed64"
            case .string, .bytes, .message, .group: ".lengthDelimited"
            default: ".varint"
        }
    }
}
