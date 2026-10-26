import Testing

@testable import AemiProtobufCore

struct FrameAsyncSequenceTests {
    private func source(_ chunks: [[UInt8]]) -> AsyncStream<[UInt8]> {
        AsyncStream { continuation in
            for chunk in chunks { continuation.yield(chunk) }
            continuation.finish()
        }
    }

    @Test func `frames arrive whole from chunks that split them anywhere`() async throws {
        let messages: [[UInt8]] = [[1, 2, 3], [], [UInt8](repeating: 9, count: 50)]
        let stream = messages.flatMap { FrameEncoder.grpc($0) }
        let chunks = stride(from: 0, to: stream.count, by: 3).map { Array(stream[$0 ..< min($0 + 3, stream.count)]) }
        var got: [[UInt8]] = []
        for try await frame in FrameAsyncSequence(source(chunks), format: .grpc) { got.append(frame.payload) }
        #expect(got == messages)
    }

    @Test func `a source that ends inside a frame throws truncated`() async {
        let bytes: [UInt8] = [0, 0, 0, 0, 4, 1]
        await #expect(throws: FrameError.truncated(buffered: 6)) {
            for try await _ in FrameAsyncSequence(source([bytes]), format: .grpc) {}
        }
    }

    @Test func `an oversized length throws before the payload is awaited`() async {
        let stream = AsyncThrowingStream<[UInt8], any Error> { continuation in
            continuation.yield([0, 0xFF, 0xFF, 0xFF, 0xFF])
            // never finishes: the sequence must not wait for 4 GiB
        }
        await #expect(throws: FrameError.lengthExceedsLimit(declared: 0xFFFF_FFFF, limit: 1_000, at: 0)) {
            for try await _ in FrameAsyncSequence(stream, format: .grpc, maxFrameBytes: 1_000) {}
        }
    }

    @Test func `the source's own error is rethrown`() async {
        struct Boom: Error, Equatable {}
        let stream = AsyncThrowingStream<[UInt8], any Error> { continuation in
            continuation.yield(FrameEncoder.varintDelimited([1]))
            continuation.finish(throwing: Boom())
        }
        await #expect(throws: Boom.self) {
            for try await _ in FrameAsyncSequence(stream, format: .varintDelimited) {}
        }
    }

    /// A source that counts how often it is asked.
    private final class Counting: AsyncSequence, @unchecked Sendable {
        var asks = 0
        let chunks: [[UInt8]]

        init(_ chunks: [[UInt8]]) { self.chunks = chunks }

        struct Iterator: AsyncIteratorProtocol {
            let owner: Counting
            var index = 0

            mutating func next() async -> [UInt8]? {
                owner.asks += 1
                defer { index += 1 }
                return index < owner.chunks.count ? owner.chunks[index] : nil
            }
        }

        func makeAsyncIterator() -> Iterator { Iterator(owner: self) }
    }

    @Test func `a finished sequence does not ask its source again`() async throws {
        let source = Counting([FrameEncoder.varintDelimited([1])])
        var iterator = FrameAsyncSequence(source, format: .varintDelimited).makeAsyncIterator()
        #expect(try await iterator.next() == Frame(payload: [1]))
        #expect(try await iterator.next() == nil)
        let asked = source.asks
        #expect(try await iterator.next() == nil)
        #expect(try await iterator.next() == nil)
        #expect(source.asks == asked)
    }
}
