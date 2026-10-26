import AemiProtobufCore

/// The same chain of nested objects in both formats: `{"c":{"c":...1}}` and field 1 holding field 1 ... holding varint 1.
public enum Nesting {
    public static func json(depth: Int) -> [UInt8] {
        Array((String(repeating: "{\"c\":", count: depth) + "1" + String(repeating: "}", count: depth)).utf8)
    }

    /// - Precondition: `depth` is below the writer's default nesting limit (100); this is a benchmark fixture.
    public static func protobuf(depth: Int) -> [UInt8] {
        var innermost = WireWriter()
        innermost.appendTag(2, .varint)
        innermost.appendVarint(1)
        var bytes = innermost.bytes
        for _ in 0 ..< depth {
            var w = WireWriter()
            w.appendTag(1, .lengthDelimited)
            w.appendBytes(bytes)
            bytes = w.bytes
        }
        return bytes
    }
}
