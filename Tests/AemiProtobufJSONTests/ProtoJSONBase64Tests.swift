import Testing

@testable import AemiProtobufJSON

struct ProtoJSONBase64Tests {
    @Test func `encoding matches the legacy encoder for every length`() {
        var generator = SystemRandomNumberGenerator()
        for length in 0 ... 300 {
            let bytes = (0 ..< length).map { _ in UInt8.random(in: 0 ... 255, using: &generator) }
            #expect(ProtoJSONBase64.encode(bytes) == LegacyProtoJSONBase64.encode(bytes), "length \(length)")
        }
        let large: [UInt8] = (0 ..< 100_003).map { (i: Int) -> UInt8 in UInt8(truncatingIfNeeded: i &* 31) }
        #expect(ProtoJSONBase64.encode(large) == LegacyProtoJSONBase64.encode(large))
    }

    @Test func `decoding matches the legacy decoder on valid and damaged text`() {
        var generator = SystemRandomNumberGenerator()
        let pool = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/-_=\n !\u{e9}".utf8)
        var checks = 0
        for length in 0 ... 140 {
            for _ in 0 ..< 40 {
                // Random text over the standard, URL-safe, padding and junk characters.
                let random = String(
                    decoding: (0 ..< length).map { _ in pool.randomElement(using: &generator)! },
                    as: UTF8.self
                )
                #expect(ProtoJSONBase64.decode(random) == LegacyProtoJSONBase64.decode(random), "\(random)")
                // Real encodings, then damaged: URL-safe spelling, stripped padding, one replaced character.
                let bytes = (0 ..< length).map { _ in UInt8.random(in: 0 ... 255, using: &generator) }
                let encoded = LegacyProtoJSONBase64.encode(bytes)
                let urlSafe = encoded.replacing("+", with: "-").replacing("/", with: "_")
                let stripped = String(encoded.prefix { $0 != "=" })
                var variants: [String] = [encoded, urlSafe, stripped, encoded + "=", encoded + "A", "=" + encoded]
                var broken = Array(encoded.utf8)
                if !broken.isEmpty {
                    broken[Int.random(in: 0 ..< broken.count, using: &generator)] = pool.randomElement(
                        using: &generator
                    )!
                    variants.append(String(decoding: broken, as: UTF8.self))
                }
                for variant in variants {
                    #expect(ProtoJSONBase64.decode(variant) == LegacyProtoJSONBase64.decode(variant), "\(variant)")
                    checks += 1
                }
            }
        }
        #expect(checks > 5_000)
    }

    @Test func `both alphabets may be mixed in one string, as the mapping allows`() {
        #expect(ProtoJSONBase64.decode("-_-_") == LegacyProtoJSONBase64.decode("-_-_"))
        #expect(ProtoJSONBase64.decode("+_+/") == LegacyProtoJSONBase64.decode("+_+/"))
        #expect(ProtoJSONBase64.decode("+_+/") != nil)
    }

    @Test func `large payloads round trip`() {
        let large: [UInt8] = (0 ..< 1_000_003).map { (i: Int) -> UInt8 in UInt8(truncatingIfNeeded: i &* 31) }
        #expect(ProtoJSONBase64.decode(ProtoJSONBase64.encode(large)) == large)
    }
}
