/// Numbers as the JSON mapping reads them: integers exactly from their text, whatever its form (`1e2` is 100, `1.0` is 1,
/// `1.5` is no integer), and floating-point values from a number or the strings `NaN`, `Infinity` and `-Infinity`.
enum ProtoJSONNumber {
    /// A JSON number's parts: sign, integer digits, fraction digits, exponent.
    struct NumberParts {
        let negative: Bool
        let integer: String
        let fraction: String
        let exponent: Int
    }

    /// An integer's sign and magnitude, or `nil` if `text` is not a JSON number with an integral value that fits 64 bits.
    static func integer(_ text: String) -> (negative: Bool, magnitude: UInt64)? {
        guard let parts = split(text) else { return nil }
        var digits = parts.integer + parts.fraction
        var exponent = parts.exponent - parts.fraction.count
        while exponent < 0, digits.last == "0" {
            digits.removeLast()
            exponent += 1
        }
        guard exponent >= 0 else { return nil }
        let significant = digits.drop { $0 == "0" }
        guard significant.count + exponent <= 20 || significant.isEmpty else { return nil }
        var magnitude: UInt64 = 0
        for digit in significant.utf8 {
            let (times, overflow) = magnitude.multipliedReportingOverflow(by: 10)
            let (sum, carry) = times.addingReportingOverflow(UInt64(digit - 48))
            guard !overflow, !carry else { return nil }
            magnitude = sum
        }
        for _ in 0 ..< (significant.isEmpty ? 0 : exponent) {
            let (times, overflow) = magnitude.multipliedReportingOverflow(by: 10)
            guard !overflow else { return nil }
            magnitude = times
        }
        return (parts.negative, magnitude)
    }

    /// The parts of a JSON number (RFC 8259 grammar): sign, integer digits, fraction digits, and the exponent; `nil` for
    /// anything else, white space included.
    // @fc:disable cut-then-decode -- every slice decoded in split is a `prefix` of ASCII digits, cut only after ASCII
    // bytes, so no character straddles a cut
    static func split(_ text: String) -> NumberParts? {
        var bytes = Substring(text).utf8[...]
        let negative = bytes.first == UInt8(ascii: "-")
        if negative { bytes = bytes.dropFirst() }
        let integer = bytes.prefix { $0 >= 48 && $0 <= 57 }
        guard !integer.isEmpty, integer.count == 1 || integer.first != 48 else { return nil }
        bytes = bytes.dropFirst(integer.count)
        var fraction = Substring("").utf8[...]
        if bytes.first == UInt8(ascii: ".") {
            fraction = bytes.dropFirst().prefix { $0 >= 48 && $0 <= 57 }
            guard !fraction.isEmpty else { return nil }
            bytes = bytes.dropFirst(fraction.count + 1)
        }
        var exponent = 0
        if let marker = bytes.first, marker == UInt8(ascii: "e") || marker == UInt8(ascii: "E") {
            bytes = bytes.dropFirst()
            let sign = bytes.first
            if sign == UInt8(ascii: "+") || sign == UInt8(ascii: "-") { bytes = bytes.dropFirst() }
            let digits = bytes.prefix { $0 >= 48 && $0 <= 57 }
            guard !digits.isEmpty, digits.count <= 6, let value = Int(String(decoding: digits, as: UTF8.self)) else {
                return nil
            }
            exponent = sign == UInt8(ascii: "-") ? -value : value
            bytes = bytes.dropFirst(digits.count)
        }
        guard bytes.isEmpty else { return nil }
        return NumberParts(
            negative: negative, integer: String(decoding: integer, as: UTF8.self),
            fraction: String(decoding: fraction, as: UTF8.self), exponent: exponent)
    }
    // @fc:enable cut-then-decode

    /// A `double` from a JSON number's text, or from one of the three strings; `nil` for other text and for a finite number
    /// too large for a `double`.
    static func double(_ text: String, quoted: Bool) -> Double? {
        if quoted {
            switch text {
                case "NaN": return .nan
                case "Infinity": return .infinity
                case "-Infinity": return -.infinity
                default: break
            }
        }
        guard split(text) != nil, let value = Double(text), value.isFinite else { return nil }
        return value
    }

    /// A `float` likewise; a finite value beyond `Float`'s range is refused rather than rounded to infinity.
    static func float(_ text: String, quoted: Bool) -> Float? {
        guard let wide = double(text, quoted: quoted) else { return nil }
        guard wide.isFinite else { return Float(wide) }
        guard let value = Float(text), value.isFinite else { return nil }
        return value
    }
}
