/// A push parser: feed it whatever bytes arrive, however they are split, and take the complete frames out.
///
/// It never holds more than one frame and its header. A declared length over ``maxFrameBytes`` is refused as soon as the header
/// is complete, so a hostile length cannot make it allocate or wait. After an error the decoder is finished: every later call
/// repeats the error, because the stream's framing is lost.
///
/// - Complexity: amortized O(bytes pushed); the buffer is compacted when more than half of it has been consumed.
public struct FrameDecoder: Sendable {
    public let format: FrameFormat
    /// The largest payload accepted. 4 MiB is gRPC's default maximum message size.
    public let maxFrameBytes: Int

    private var buffer: [UInt8] = []
    private var head = 0
    /// Stream offset of `buffer[head]`.
    private var consumed = 0
    private var failure: FrameError?

    public init(format: FrameFormat, maxFrameBytes: Int = 4 * 1_024 * 1_024) {
        self.format = format
        self.maxFrameBytes = max(0, maxFrameBytes)
    }

    /// Bytes the decoder is holding, consumed ones included until it compacts. Always below twice the unread bytes plus 4 KiB.
    var storedCount: Int { buffer.count }

    /// Bytes pushed and not yet part of a returned frame.
    public var bufferedCount: Int { buffer.count - head }

    /// Adds bytes from the stream. Never throws: framing is checked by ``next()``.
    public mutating func push(_ bytes: some Sequence<UInt8>) {
        guard failure == nil else { return }
        buffer.append(contentsOf: bytes)
    }

    /// The next complete frame, or `nil` if more bytes are needed.
    /// - Throws: ``FrameError`` for a length over the limit, a bad flag or a malformed length.
    public mutating func next() throws(FrameError) -> Frame? {
        if let failure { throw failure }
        do throws(FrameError) {
            guard let (headerSize, flag, length) = try header() else { return nil }
            guard bufferedCount - headerSize >= length else { return nil }
            let start = head + headerSize
            let frame = Frame(isCompressed: flag & 1 == 1, payload: Array(buffer[start ..< start + length]))
            advance(headerSize + length)
            return frame
        } catch {
            failure = error
            throw error
        }
    }

    /// Call when the stream ends.
    /// - Throws: ``FrameError/truncated(buffered:)`` if a frame is only partly there.
    public func finish() throws(FrameError) {
        if let failure { throw failure }
        if bufferedCount > 0 { throw .truncated(buffered: bufferedCount) }
    }

    /// The header at `head`: its size, the flag, the payload length; `nil` until it is complete.
    private func header() throws(FrameError) -> (Int, UInt8, Int)? {
        switch format {
            case .grpc:
                guard bufferedCount >= 5 else { return nil }
                let flag = buffer[head]
                guard flag & 0xFE == 0 else { throw .invalidFlag(flag, at: consumed) }
                var length: UInt64 = 0
                for index in 1 ... 4 { length = length << 8 | UInt64(buffer[head + index]) }
                try check(length)
                return (5, flag, Int(length))
            case .varintDelimited:
                var length: UInt64 = 0
                var shift: UInt64 = 0
                var index = 0
                while head + index < buffer.count {
                    let byte = buffer[head + index]
                    index += 1
                    // The tenth byte may carry only bit 63; an eleventh byte, or a larger tenth, does not fit.
                    guard index < 10 || (index == 10 && byte <= 1) else { throw .malformedLength(at: consumed) }
                    length |= UInt64(byte & 0x7F) << shift
                    if byte < 0x80 {
                        try check(length)
                        return (index, 0, Int(length))
                    }
                    shift += 7
                }
                return nil
        }
    }

    private func check(_ declared: UInt64) throws(FrameError) {
        guard declared <= UInt64(maxFrameBytes) else {
            throw .lengthExceedsLimit(declared: declared, limit: maxFrameBytes, at: consumed)
        }
    }

    private mutating func advance(_ count: Int) {
        head += count
        consumed += count
        if head > 4_096, head * 2 > buffer.count {
            buffer.removeSubrange(..<head)
            head = 0
        }
    }
}
