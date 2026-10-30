/// C's `%.Pg` for doubles, computed from the value's exact decimal expansion, so the rounding is printf's (half to even on the
/// exact value); and protoc's `SimpleDtoa` / `SimpleFtoa`, which try 15 (6) digits and fall back to 17 (9) when they do not
/// read back. protoc writes float and double `default_value`s this way.
enum CFloatFormat {
    static func simple(_ value: Double) -> String {
        if let special = special(value) { return special }
        let short = g(value, precision: 15)
        return Double(short) == value ? short : g(value, precision: 17)
    }

    static func simple(_ value: Float) -> String {
        if let special = special(Double(value)) { return special }
        let short = g(Double(value), precision: 6)
        return Float(short) == value ? short : g(Double(value), precision: 9)
    }

    private static func special(_ value: Double) -> String? {
        if value.isNaN { return "nan" }
        if value.isInfinite { return value < 0 ? "-inf" : "inf" }
        return nil
    }

    /// `%.{precision}g` of a finite value.
    static func g(_ value: Double, precision: Int) -> String {
        let sign = value.sign == .minus ? "-" : ""
        guard value != 0 else { return sign + "0" }
        var (digits, point) = exactDigits(abs(value))
        if digits.count > precision {
            let rest = digits[precision...]
            let half = rest.first ?? 0
            let tail = rest.dropFirst().contains { $0 != 0 }
            digits = Array(digits[..<precision])
            if half > 5 || half == 5 && (tail || (digits.last ?? 0) % 2 == 1) {
                var index = digits.count - 1
                while index >= 0, digits[index] == 9 {
                    digits[index] = 0
                    index -= 1
                }
                if index < 0 {
                    digits.insert(1, at: 0)
                    digits.removeLast()
                    point += 1
                } else {
                    digits[index] += 1
                }
            }
        }
        while digits.count > 1, digits.last == 0 { digits.removeLast() }
        let exponent = point - 1
        let text = digits.map { String($0) }.joined()
        if exponent < -4 || exponent >= precision {
            let mantissa = text.count > 1 ? String(text.prefix(1)) + "." + text.dropFirst() : text
            let magnitude = String(abs(exponent))
            return sign + mantissa + "e" + (exponent < 0 ? "-" : "+") + (magnitude.count < 2 ? "0" : "") + magnitude
        }
        if exponent < 0 { return sign + "0." + String(repeating: "0", count: -exponent - 1) + text }
        if text.count <= exponent + 1 { return sign + text + String(repeating: "0", count: exponent + 1 - text.count) }
        return sign + String(text.prefix(exponent + 1)) + "." + text.dropFirst(exponent + 1)
    }

    /// The exact decimal digits of a positive finite double, and where the decimal point goes (value = 0.digits × 10^point).
    private static func exactDigits(_ value: Double) -> ([UInt8], Int) {
        let subnormal = value.exponentBitPattern == 0
        let mantissa = value.significandBitPattern | (subnormal ? 0 : 1 << 52)
        let exponent = subnormal ? -1074 : Int(value.exponentBitPattern) - 1075
        var limbs: [UInt64] = [
            mantissa % 1_000_000_000, mantissa / 1_000_000_000 % 1_000_000_000, mantissa / 1_000_000_000_000_000_000
        ]
        func multiply(_ factor: UInt64) {
            var carry: UInt64 = 0
            for index in limbs.indices {
                let product = limbs[index] * factor + carry
                limbs[index] = product % 1_000_000_000
                carry = product / 1_000_000_000
            }
            while carry > 0 {
                limbs.append(carry % 1_000_000_000)
                carry /= 1_000_000_000
            }
        }
        var remaining = abs(exponent)
        while remaining > 0 {
            let step = min(remaining, exponent > 0 ? 29 : 12)
            multiply(exponent > 0 ? 1 << UInt64(step) : power(5, step))
            remaining -= step
        }
        while limbs.count > 1, limbs.last == 0 { limbs.removeLast() }
        var text = String(limbs.last ?? 0)
        for limb in limbs.dropLast().reversed() {
            let part = String(limb)
            text += String(repeating: "0", count: 9 - part.count) + part
        }
        let digits = text.utf8.map { $0 - 48 }
        return (digits, digits.count + (exponent < 0 ? exponent : 0))
    }

    private static func power(_ base: UInt64, _ count: Int) -> UInt64 {
        var result: UInt64 = 1
        for _ in 0 ..< count { result *= base }
        return result
    }
}
