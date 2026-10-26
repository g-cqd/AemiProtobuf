import AemiProtobufCore

/// The writer one encode call shares between all its encoders, and the first error any of them met. `Encoder` methods that
/// create containers cannot throw, so such an error is kept here and thrown by the next operation.
final class _ProtobufEncoderState {
    var writer: WireWriter
    let limits: WireLimits
    private var failure: (any Error)?

    init(limits: WireLimits) {
        self.limits = limits
        writer = WireWriter(limits: limits, reservingCapacity: 256)
    }

    func fail(_ error: any Error) {
        if failure == nil { failure = error }
    }

    func check() throws {
        if let failure { throw failure }
    }

    /// Runs `body` on the writer. A wire error becomes ``ProtobufEncodingError/underlying(_:)`` and is kept.
    func perform(_ body: (inout WireWriter) throws(WireError) -> Void) throws {
        try check()
        do {
            try body(&writer)
        } catch {
            let wrapped = ProtobufEncodingError.underlying(error)
            fail(wrapped)
            throw wrapped
        }
    }
}
