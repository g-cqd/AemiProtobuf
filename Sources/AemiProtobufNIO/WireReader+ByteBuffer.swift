// swift-nio interop for AemiProtobuf (roadmap 0014): a `ByteBuffer` read in place, messages written into one, frames read
// a piece at a time, and channel handlers. A superset module: `import AemiProtobufNIO` gives the macros, the coders and the
// wire core. swift-nio enters the graph only here (the `AEMIPROTOBUF_NIO`-gated product).

@_exported import AemiProtobuf
@_exported import AemiProtobufCore
public import NIOCore

extension WireReader {
    /// Runs `body` with a reader over `buffer`'s readable bytes, where they lie: no copy. The buffer's reader index is not
    /// moved.
    /// - Throws: whatever `body` throws, or ``WireError/messageTooLarge(limit:)``.
    public static func withReader<R>(
        over buffer: ByteBuffer, limits: WireLimits = .default, _ body: (inout WireReader) throws(WireError) -> R
    ) throws(WireError) -> R {
        let result: Result<R, WireError> = buffer.withUnsafeReadableBytes { raw in
            do throws(WireError) {
                return .success(try unsafe WireReader.withReader(overUnsafeBytes: raw, limits: limits, body))
            } catch {
                return .failure(error)
            }
        }
        return try result.get()
    }
}
