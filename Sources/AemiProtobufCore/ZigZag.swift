/// Zig-zag mapping: signed values to unsigned ones so that small magnitudes stay small as varints (`sint32`, `sint64`).
public enum ZigZag {
    @inlinable public static func encode(_ value: Int32) -> UInt32 { UInt32(bitPattern: (value << 1) ^ (value >> 31)) }
    @inlinable public static func encode(_ value: Int64) -> UInt64 { UInt64(bitPattern: (value << 1) ^ (value >> 63)) }
    @inlinable public static func decode(_ value: UInt32) -> Int32 {
        Int32(bitPattern: value >> 1) ^ -Int32(bitPattern: value & 1)
    }
    @inlinable public static func decode(_ value: UInt64) -> Int64 {
        Int64(bitPattern: value >> 1) ^ -Int64(bitPattern: value & 1)
    }
}
