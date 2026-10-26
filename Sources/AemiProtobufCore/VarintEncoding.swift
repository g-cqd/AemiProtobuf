/// How a signed integer becomes a varint: as its two's-complement bits (`int32`, `int64`) or zig-zag mapped (`sint32`, `sint64`).
public enum VarintEncoding: Sendable {
    case plain
    case zigzag
}
