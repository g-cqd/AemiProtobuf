import Testing

@testable import AemiProtobufCore

struct FrameDecoderTests {
    private func frames(_ stream: [UInt8], format: FrameFormat, chunks: [Range<Int>]) throws -> [Frame] {
        var decoder = FrameDecoder(format: format)
        var out: [Frame] = []
        for chunk in chunks {
            decoder.push(stream[chunk])
            while let frame = try decoder.next() { out.append(frame) }
        }
        try decoder.finish()
        return out
    }

    private static let messages: [[UInt8]] = [[], [1, 2, 3], [UInt8](repeating: 0xAB, count: 300), [7]]

    @Test(arguments: [FrameFormat.grpc, .varintDelimited])
    func `a stream split at every byte offset yields the same frames`(format: FrameFormat) throws {
        let stream = Self.messages.flatMap { FrameEncoder.frame($0, format: format) }
        let whole = try frames(stream, format: format, chunks: [0 ..< stream.count])
        #expect(whole.map(\.payload) == Self.messages)
        for cut in 0 ... stream.count {
            #expect(try frames(stream, format: format, chunks: [0 ..< cut, cut ..< stream.count]) == whole)
        }
        #expect(try frames(stream, format: format, chunks: (0 ..< stream.count).map { $0 ..< $0 + 1 }) == whole)
    }

    @Test func `the gRPC specification's example frame decodes`() throws {
        // flag 0, length 5, "hello"
        let bytes: [UInt8] = [0, 0, 0, 0, 5, 0x68, 0x65, 0x6C, 0x6C, 0x6F]
        let got = try frames(bytes, format: .grpc, chunks: [0 ..< bytes.count])
        #expect(got == [Frame(payload: Array("hello".utf8))])
        #expect(FrameEncoder.grpc(Array("hello".utf8)) == bytes)
    }

    @Test func `the compressed bit is reported and other flag bits are refused`() throws {
        #expect(
            try frames([1, 0, 0, 0, 1, 9], format: .grpc, chunks: [0 ..< 6]) == [
                Frame(isCompressed: true, payload: [9])
            ])
        for flag in [UInt8(2), 0x80, 0xFE, 0xFF] {
            var decoder = FrameDecoder(format: .grpc)
            decoder.push([flag, 0, 0, 0, 0])
            #expect(throws: FrameError.invalidFlag(flag, at: 0)) { try decoder.next() }
        }
    }

    @Test func `a declared length of 4 GiB is refused when the header is complete, with nothing buffered for it`() {
        var decoder = FrameDecoder(format: .grpc, maxFrameBytes: 1_024)
        decoder.push([0, 0xFF, 0xFF, 0xFF, 0xFF])
        #expect(throws: FrameError.lengthExceedsLimit(declared: 0xFFFF_FFFF, limit: 1_024, at: 0)) {
            try decoder.next()
        }
        decoder.push([UInt8](repeating: 0, count: 10_000))
        #expect(decoder.bufferedCount == 5, "after an error nothing more is buffered")
        #expect(throws: FrameError.self) { try decoder.next() }
        #expect(throws: FrameError.self) { try decoder.finish() }
    }

    @Test func `the limit is inclusive`() throws {
        var decoder = FrameDecoder(format: .varintDelimited, maxFrameBytes: 3)
        decoder.push([3, 1, 2, 3])
        #expect(try decoder.next()?.payload == [1, 2, 3])
        decoder.push([4])
        #expect(throws: FrameError.lengthExceedsLimit(declared: 4, limit: 3, at: 4)) { try decoder.next() }
    }

    @Test(arguments: [
        [UInt8](repeating: 0xFF, count: 11), [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x02]
    ])
    func `a varint length that does not fit 64 bits is malformed`(bytes: [UInt8]) {
        var decoder = FrameDecoder(format: .varintDelimited)
        decoder.push(bytes)
        #expect(throws: FrameError.malformedLength(at: 0)) { try decoder.next() }
    }

    @Test func `a stream that ends inside a frame is reported with what arrived`() throws {
        var decoder = FrameDecoder(format: .grpc)
        decoder.push([0, 0, 0, 0, 9, 1, 2])
        #expect(try decoder.next() == nil)
        #expect(throws: FrameError.truncated(buffered: 7)) { try decoder.finish() }
        let clean = FrameDecoder(format: .grpc)
        try clean.finish()
    }

    @Test func `many frames in one push come out in order and the buffer stays bounded`() throws {
        var decoder = FrameDecoder(format: .varintDelimited)
        let message = [UInt8](repeating: 5, count: 100)
        var count = 0
        for _ in 0 ..< 1_000 {
            decoder.push(FrameEncoder.varintDelimited(message))
            while let frame = try decoder.next() {
                #expect(frame.payload == message)
                count += 1
            }
        }
        #expect(count == 1_000 && decoder.bufferedCount == 0)
    }

    @Test func `a zero-length frame is a frame`() throws {
        #expect(try frames([0], format: .varintDelimited, chunks: [0 ..< 1]) == [Frame(payload: [])])
        #expect(try frames([0, 0, 0, 0, 0], format: .grpc, chunks: [0 ..< 5]) == [Frame(payload: [])])
    }

    @Test func `a ten-byte varint length is valid when its value is, and malformed only when it overflows`() throws {
        var padded = FrameDecoder(format: .varintDelimited)
        padded.push([UInt8](repeating: 0x80, count: 9) + [0x00])  // zero, written in ten bytes
        #expect(try padded.next() == Frame(payload: []))
        var big = FrameDecoder(format: .varintDelimited, maxFrameBytes: 100)
        big.push([UInt8](repeating: 0x80, count: 9) + [0x01])  // 2^63: fits 64 bits, exceeds the limit
        #expect(throws: FrameError.lengthExceedsLimit(declared: 1 << 63, limit: 100, at: 0)) { try big.next() }
        var overflow = FrameDecoder(format: .varintDelimited)
        overflow.push([UInt8](repeating: 0x80, count: 9) + [0x02])  // 2^64
        #expect(throws: FrameError.malformedLength(at: 0)) { try overflow.next() }
    }

    @Test func `a header split inside the varint waits instead of failing`() throws {
        var decoder = FrameDecoder(format: .varintDelimited)
        decoder.push([0xAC])
        #expect(try decoder.next() == nil)
        decoder.push([0x02] + [UInt8](repeating: 1, count: 300))
        #expect(try decoder.next()?.payload.count == 300)
    }

    @Test func `a gRPC header split before its fifth byte waits`() throws {
        var decoder = FrameDecoder(format: .grpc)
        decoder.push([0, 0, 0, 0])
        #expect(try decoder.next() == nil)
        decoder.push([1, 9])
        #expect(try decoder.next() == Frame(payload: [9]))
    }

    @Test func `consumed bytes are released, so a long stream holds a bounded buffer`() throws {
        var decoder = FrameDecoder(format: .varintDelimited)
        let message = FrameEncoder.varintDelimited([UInt8](repeating: 5, count: 100))
        var largest = 0
        for _ in 0 ..< 2_000 {
            decoder.push(message)
            _ = try decoder.next()
            largest = max(largest, decoder.storedCount)
        }
        #expect(largest < 40_000, "200 KB went through; the buffer must not keep it")
    }

    @Test func `the default frame is not compressed`() {
        #expect(FrameEncoder.frame([1], format: .grpc).first == 0)
        #expect(FrameEncoder.grpc([1]).first == 0)
        #expect(FrameEncoder.grpc([1], compressed: true).first == 1)
        #expect(FrameEncoder.frame([1], format: .grpc, compressed: true).first == 1)
        #expect(FrameEncoder.frame([1], format: .varintDelimited, compressed: true) == [1, 1])
    }

    /// Frames of exactly 64 bytes (a one-byte length and 63 of payload), so `head` lands on known values.
    private func backlog(frames count: Int) -> FrameDecoder {
        var decoder = FrameDecoder(format: .varintDelimited)
        for _ in 0 ..< count { decoder.push(FrameEncoder.varintDelimited([UInt8](repeating: 1, count: 63))) }
        return decoder
    }

    @Test func `the buffer is compacted only when more than 4 KiB and more than half of it is consumed`() throws {
        // 100 frames = 6,400 bytes. After 64 frames head is exactly 4,096: not over the limit, so no compaction.
        var decoder = backlog(frames: 100)
        for _ in 0 ..< 64 { _ = try decoder.next() }
        #expect(decoder.storedCount == 6_400)
        // One more frame: head 4,160 is over 4,096 and over half of 6,400, so the consumed prefix is dropped.
        _ = try decoder.next()
        #expect(decoder.storedCount == 6_400 - 4_160)

        // 130 frames = 8,320 bytes. After 65 frames head is 4,160 = exactly half: not more than half, so no compaction.
        var half = backlog(frames: 130)
        for _ in 0 ..< 65 { _ = try half.next() }
        #expect(half.storedCount == 8_320)
        _ = try half.next()
        #expect(half.storedCount == 8_320 - 4_224)

        // A backlog far past both limits is compacted as it is read, and what remains is still decoded correctly.
        var big = backlog(frames: 2_000)
        for _ in 0 ..< 1_500 { _ = try big.next() }
        #expect(big.storedCount < 64 * 1_000)
        var rest = 0
        while let frame = try big.next() {
            #expect(frame.payload.count == 63)
            rest += 1
        }
        #expect(rest == 500)
    }
}
