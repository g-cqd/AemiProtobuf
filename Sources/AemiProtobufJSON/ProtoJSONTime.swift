/// The text forms of `google.protobuf.Timestamp` (RFC 3339, years 1 to 9999) and `google.protobuf.Duration` (seconds with an
/// `s`, at most 10,000 years either way). Fractions are written with 0, 3, 6 or 9 digits and read with 1 to 9.
enum ProtoJSONTime {
    static let minTimestamp: Int64 = -62_135_596_800  // 0001-01-01T00:00:00Z
    static let maxTimestamp: Int64 = 253_402_300_799  // 9999-12-31T23:59:59Z
    static let maxDuration: Int64 = 315_576_000_000

    /// Seconds and nanoseconds since the epoch, or `nil` for text that is not `YYYY-MM-DDTHH:MM:SS[.f…](Z|±HH:MM)` in range.
    static func timestamp(_ text: String) -> (seconds: Int64, nanos: Int32)? {
        let b = Array(text.utf8)
        guard b.count >= 20, let year = digits(b, 0, 4), b[4] == UInt8(ascii: "-"), let month = digits(b, 5, 2),
            b[7] == UInt8(ascii: "-"), let day = digits(b, 8, 2), b[10] == UInt8(ascii: "T"),
            let hour = digits(b, 11, 2),
            b[13] == UInt8(ascii: ":"), let minute = digits(b, 14, 2), b[16] == UInt8(ascii: ":"),
            let second = digits(b, 17, 2)
        else { return nil }
        var index = 19
        guard let nanos = fraction(b, &index), index < b.count else { return nil }
        var offset = 0
        if b[index] == UInt8(ascii: "Z") {
            index += 1
        } else if b[index] == UInt8(ascii: "+") || b[index] == UInt8(ascii: "-") {
            guard index + 6 <= b.count, let hours = digits(b, index + 1, 2), b[index + 3] == UInt8(ascii: ":"),
                let minutes = digits(b, index + 4, 2), hours <= 23, minutes <= 59
            else { return nil }
            offset = (hours * 60 + minutes) * 60 * (b[index] == UInt8(ascii: "-") ? -1 : 1)
            index += 6
        }
        guard index == b.count, (1 ... 9999).contains(year), (1 ... 12).contains(month),
            (1 ... daysIn(month, year)).contains(day), hour <= 23, minute <= 59, second <= 59
        else { return nil }
        let seconds =
            Int64(daysFromCivil(year, month, day)) * 86_400 + Int64(hour * 3_600 + minute * 60 + second) - Int64(offset)
        guard (minTimestamp ... maxTimestamp).contains(seconds) else { return nil }
        return (seconds, Int32(nanos))
    }

    /// The RFC 3339 text in UTC, or `nil` outside years 1 to 9999 or for nanoseconds outside `0 ..< 1e9`.
    static func timestamp(seconds: Int64, nanos: Int32) -> String? {
        guard (minTimestamp ... maxTimestamp).contains(seconds), (0 ..< 1_000_000_000).contains(nanos) else {
            return nil
        }
        let days = seconds >= 0 ? seconds / 86_400 : (seconds - 86_399) / 86_400
        let rest = Int(seconds - days * 86_400)
        let (year, month, day) = civilFromDays(Int(days))
        return pad(year, 4) + "-" + pad(month, 2) + "-" + pad(day, 2) + "T" + pad(rest / 3_600, 2) + ":"
            + pad(rest / 60 % 60, 2) + ":" + pad(rest % 60, 2) + fractionText(Int(nanos)) + "Z"
    }

    /// Seconds and nanoseconds, both of the text's sign, or `nil` for text that is not `[-]S[.f…]s` within 10,000 years.
    static func duration(_ text: String) -> (seconds: Int64, nanos: Int32)? {
        var b = Array(text.utf8)
        guard b.last == UInt8(ascii: "s") else { return nil }
        b.removeLast()
        let negative = b.first == UInt8(ascii: "-")
        let start = negative ? 1 : 0
        var index = start
        while index < b.count, (48 ... 57).contains(b[index]) { index += 1 }
        guard index > start, index - start <= 12, let whole = digits(b, start, index - start),
            let nanos = fraction(b, &index), index == b.count, Int64(whole) <= maxDuration
        else { return nil }
        let sign: Int64 = negative ? -1 : 1
        return (Int64(whole) * sign, Int32(Int64(nanos) * sign))
    }

    /// The duration's text, or `nil` when it is out of range or its parts' signs differ.
    static func duration(seconds: Int64, nanos: Int32) -> String? {
        guard abs(seconds) <= maxDuration, abs(nanos) < 1_000_000_000,
            !(seconds > 0 && nanos < 0), !(seconds < 0 && nanos > 0)
        else { return nil }
        let sign = seconds < 0 || nanos < 0 ? "-" : ""
        return sign + String(abs(seconds)) + fractionText(Int(abs(nanos))) + "s"
    }

    /// Reads `.` and one to nine digits at `index` as nanoseconds (0 when there is no `.`), moving `index` past them.
    private static func fraction(_ b: [UInt8], _ index: inout Int) -> Int? {
        guard index < b.count, b[index] == UInt8(ascii: ".") else { return 0 }
        let start = index + 1
        var end = start
        while end < b.count, (48 ... 57).contains(b[end]) { end += 1 }
        guard (1 ... 9).contains(end - start), let value = digits(b, start, end - start) else { return nil }
        index = end
        var scale = 1
        for _ in 0 ..< 9 - (end - start) { scale *= 10 }
        return value * scale
    }

    private static func fractionText(_ nanos: Int) -> String {
        if nanos == 0 { return "" }
        if nanos % 1_000_000 == 0 { return "." + pad(nanos / 1_000_000, 3) }
        if nanos % 1_000 == 0 { return "." + pad(nanos / 1_000, 6) }
        return "." + pad(nanos, 9)
    }

    private static func digits(_ b: [UInt8], _ start: Int, _ count: Int) -> Int? {
        guard start >= 0, start + count <= b.count else { return nil }
        var value = 0
        for index in start ..< start + count {
            guard (48 ... 57).contains(b[index]) else { return nil }
            value = value * 10 + Int(b[index] - 48)
        }
        return value
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let text = String(value)
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }

    private static func daysIn(_ month: Int, _ year: Int) -> Int {
        switch month {
            case 2: year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) ? 29 : 28
            case 4, 6, 9, 11: 30
            default: 31
        }
    }

    /// Days since 1970-01-01 of a proleptic Gregorian date (Howard Hinnant's `days_from_civil`).
    private static func daysFromCivil(_ year: Int, _ month: Int, _ day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /// The date of a day count since 1970-01-01 (Hinnant's `civil_from_days`).
    private static func civilFromDays(_ count: Int) -> (Int, Int, Int) {
        let z = count + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let day = doy - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }
}
