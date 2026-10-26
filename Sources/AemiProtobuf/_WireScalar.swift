import AemiKernel
import AemiProtobufCore

/// One scalar as it sits on the wire: its wire type and the bits it carries. Every Swift integer, `Bool`, `Float` and
/// `Double` the coders accept converts to and from this, so the keyed, unkeyed and single-value containers share one
/// encoding and one set of range checks.
enum _WireScalar: Equatable {
    case varint(UInt64)
    case fixed32(UInt32)
    case fixed64(UInt64)

    var wireType: WireType {
        switch self {
            case .varint: .varint
            case .fixed32: .fixed32
            case .fixed64: .fixed64
        }
    }

    /// Whether the bits are zero: proto3 leaves such a field out unless the field has explicit presence.
    var isDefault: Bool {
        switch self {
            case .varint(let v), .fixed64(let v): v == 0
            case .fixed32(let v): v == 0
        }
    }

    /// Signed values are sign-extended to 64 bits, as `int32` and `int64` require.
    static func signed(_ value: Int64) -> Self { .varint(UInt64(bitPattern: value)) }

    /// Writes the payload, without a tag.
    func write(to writer: inout WireWriter) {
        switch self {
            case .varint(let v): writer.appendVarint(v)
            case .fixed32(let v): writer.appendFixed32(v)
            case .fixed64(let v): writer.appendFixed64(v)
        }
    }

    /// Appends the payload to a packed run.
    func append(to bytes: inout [UInt8]) {
        switch self {
            case .varint(let v): Varint.append(v, to: &bytes)
            case .fixed32(let v):
                for shift in stride(from: 0, to: 32, by: 8) {
                    bytes.append(UInt8(truncatingIfNeeded: v >> UInt32(shift)))
                }
            case .fixed64(let v):
                for shift in stride(from: 0, to: 64, by: 8) {
                    bytes.append(UInt8(truncatingIfNeeded: v >> UInt64(shift)))
                }
        }
    }
}
