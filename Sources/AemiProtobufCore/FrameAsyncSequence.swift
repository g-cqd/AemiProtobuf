/// The frames of an asynchronous byte source, as the source delivers it in chunks of any size.
///
/// Each element is one complete ``Frame``. The sequence ends when the source ends, throws ``FrameError`` if it ends inside a
/// frame, and rethrows the source's own error. Cancellation is the source's: this sequence awaits only the source's `next()`.
public struct FrameAsyncSequence<Base: AsyncSequence>: AsyncSequence where Base.Element: Sequence<UInt8> {
    public typealias Element = Frame

    private let base: Base
    private let format: FrameFormat
    private let maxFrameBytes: Int

    public init(_ base: Base, format: FrameFormat, maxFrameBytes: Int = 4 * 1_024 * 1_024) {
        self.base = base
        self.format = format
        self.maxFrameBytes = maxFrameBytes
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), decoder: FrameDecoder(format: format, maxFrameBytes: maxFrameBytes))
    }

    public struct Iterator: AsyncIteratorProtocol {
        var base: Base.AsyncIterator
        var decoder: FrameDecoder
        var ended = false

        public mutating func next() async throws -> Frame? {
            while true {
                if let frame = try decoder.next() { return frame }
                guard !ended, let chunk = try await base.next() else {
                    ended = true
                    try decoder.finish()
                    return nil
                }
                decoder.push(chunk)
            }
        }
    }
}
