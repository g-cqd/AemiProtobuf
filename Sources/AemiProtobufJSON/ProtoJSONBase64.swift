internal import AemiKernel

/// Base64 as the JSON mapping uses it for `bytes`: written in the standard alphabet with padding, read in either the standard or
/// the URL-safe alphabet, padded or not.
///
/// Both directions go through `AemiKernel.Base64`, so they take its SIMD block kernels where the pinned aemi has them. The
/// codec reads one alphabet at a time, and the mapping allows both, even mixed in one string: text that is plain standard
/// Base64 (the common case) decodes in one pass, and only text the first pass rejects and that holds `-` or `_` is translated to
/// the standard alphabet and decoded again. The answers are those of the hand-written decoder this replaced (the tests keep it
/// as the oracle): padding optional but exact, any trailing bits accepted, no whitespace.
enum ProtoJSONBase64 {
    private static let options: Base64.Options = {
        var options = Base64.Options.lenient
        options.padding = .optional
        options.trailingBits = .lenient
        options.whitespace = .reject
        options.alphabet = .standard
        return options
    }()

    static func encode(_ bytes: [UInt8]) -> String {
        Base64.encodedString(bytes, options: .strict)
    }

    /// - Returns: the bytes, or `nil` for a character outside both alphabets, misplaced padding, or a dangling sixth bit.
    static func decode(_ text: String) -> [UInt8]? {
        var copy = text
        return copy.withUTF8 { utf8 -> [UInt8]? in
            if let bytes = try? Base64.decode(utf8, options: options) { return bytes }
            // Only an input that holds the URL-safe symbols can be saved by translating them.
            guard utf8.contains(UInt8(ascii: "-")) || utf8.contains(UInt8(ascii: "_")) else { return nil }
            let translated = utf8.map { byte -> UInt8 in
                switch byte {
                    case UInt8(ascii: "-"): UInt8(ascii: "+")
                    case UInt8(ascii: "_"): UInt8(ascii: "/")
                    default: byte
                }
            }
            return try? Base64.decode(translated, options: options)
        }
    }
}
