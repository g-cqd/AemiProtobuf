/// The code for one field value: how it is written, read and tested against its default. All strings are Swift source
/// that refers to the writer `w` and the reader `r` of the generated members.
struct ProtoFieldScalar {
    let kind: ProtoKind
    let swiftType: String
    /// The statement that keeps an enumeration number with no case (`__raw`), or nil to drop it.
    var unknown: String? = nil

    /// `true` when `value` is not the proto3 default and so must be written.
    func isSet(_ value: String) -> String {
        switch kind {
            case .bool: value
            case .string, .bytes: "!\(value).isEmpty"
            case .enumeration: "\(value).rawValue != 0"
            case .message, .group: "true"
            default: "\(value) != 0"
        }
    }

    /// The statement that writes the value's payload, without a tag.
    func write(_ value: String) -> String {
        switch kind {
            case .int32: "w.appendInt32(Int32(truncatingIfNeeded: \(value)))"
            case .int64: "w.appendVarint(UInt64(bitPattern: Int64(truncatingIfNeeded: \(value))))"
            case .uint32, .uint64: "w.appendVarint(UInt64(truncatingIfNeeded: \(value)))"
            case .sint32: "w.appendVarint(UInt64(ZigZag.encode(Int32(truncatingIfNeeded: \(value)))))"
            case .sint64: "w.appendVarint(ZigZag.encode(Int64(truncatingIfNeeded: \(value))))"
            case .fixed32: "w.appendFixed32(UInt32(truncatingIfNeeded: \(value)))"
            case .sfixed32: "w.appendFixed32(UInt32(bitPattern: Int32(truncatingIfNeeded: \(value))))"
            case .fixed64: "w.appendFixed64(UInt64(truncatingIfNeeded: \(value)))"
            case .sfixed64: "w.appendFixed64(UInt64(bitPattern: Int64(truncatingIfNeeded: \(value))))"
            case .bool: "w.appendVarint(\(value) ? 1 : 0)"
            case .float: "w.appendFloat(\(value))"
            case .double: "w.appendDouble(\(value))"
            case .string: "w.appendString(\(value))"
            case .bytes: swiftType == "Data" ? "w.appendBytes([UInt8](\(value)))" : "w.appendBytes(\(value))"
            case .enumeration: "w.appendInt32(\(value).rawValue)"
            case .message, .group: "try \(value).__aepbEncode(into: &w)"
        }
    }

    /// The expression that reads one value of the field's type from `r`. An enumeration is read as its raw number; see
    /// ``readsOptionalValue``.
    var read: String {
        switch kind {
            case .int32: "\(swiftType)(truncatingIfNeeded: try r.readInt32())"
            case .int64: "\(swiftType)(truncatingIfNeeded: Int64(bitPattern: try r.readVarint()))"
            case .uint32: "\(swiftType)(truncatingIfNeeded: UInt32(truncatingIfNeeded: try r.readVarint()))"
            case .uint64: "\(swiftType)(truncatingIfNeeded: try r.readVarint())"
            case .sint32:
                "\(swiftType)(truncatingIfNeeded: ZigZag.decode(UInt32(truncatingIfNeeded: try r.readVarint())))"
            case .sint64: "\(swiftType)(truncatingIfNeeded: ZigZag.decode(try r.readVarint()))"
            case .fixed32: "\(swiftType)(truncatingIfNeeded: try r.readFixed32())"
            case .sfixed32: "\(swiftType)(truncatingIfNeeded: Int32(bitPattern: try r.readFixed32()))"
            case .fixed64: "\(swiftType)(truncatingIfNeeded: try r.readFixed64())"
            case .sfixed64: "\(swiftType)(truncatingIfNeeded: Int64(bitPattern: try r.readFixed64()))"
            case .bool: "try r.readVarint() != 0"
            case .float: "try r.readFloat()"
            case .double: "try r.readDouble()"
            case .string: "try r.readString()"
            case .bytes: swiftType == "Data" ? "Data(try r.readBytes())" : "try r.readBytes()"
            case .enumeration: "ProtoEnumeration.value(\(swiftType).self, __raw)"
            case .message:
                "try r.readMessage { r throws(WireError) in try \(swiftType).__aepbDecode(from: &r) }"
            case .group:
                "try r.readGroup(tag) { r throws(WireError) in try \(swiftType).__aepbDecode(from: &r) }"
        }
    }

    /// Whether ``read`` yields an optional that is `nil` for an unknown enumeration number, which the field keeps its
    /// previous value for.
    var readsOptionalValue: Bool { kind == .enumeration }

    /// Whether a packed run of this field is the raw little-endian words of the Swift array, so it can be copied in one move:
    /// the Swift type has exactly the width and bit layout of the wire type.
    var isBulkCopyable: Bool {
        switch (kind, swiftType) {
            case (.float, "Float"), (.double, "Double"), (.fixed32, "UInt32"), (.sfixed32, "Int32"),
                (.fixed64, "UInt64"), (.sfixed64, "Int64"):
                true
            default: false
        }
    }

    /// The extra argument of the core's packed-varint calls (`, .zigzag`, or empty) when the Swift type is exactly the one the
    /// core reads and writes in bulk (`Int32`, `Int64`, `UInt32`, `UInt64`); `nil` otherwise.
    var bulkVarintEncoding: String? {
        switch (kind, swiftType) {
            case (.int32, "Int32"), (.int64, "Int64"), (.uint32, "UInt32"), (.uint64, "UInt64"): ""
            case (.sint32, "Int32"), (.sint64, "Int64"): ", .zigzag"
            default: nil
        }
    }
}
