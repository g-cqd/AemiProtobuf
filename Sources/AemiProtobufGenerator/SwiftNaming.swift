/// How protobuf names become Swift names, as swift-protobuf spells them: a package prefixes its top-level types (each
/// package component in upper camel case, joined by `_`), fields in lower camel case, enumeration values in lower camel case
/// without the enumeration's own name as a prefix.
enum SwiftNaming {
    static let keywords: Set<String> = Set(
        """
        associatedtype class deinit enum extension fileprivate func import init inout internal let open
        operator private precedencegroup protocol public rethrows static struct subscript typealias var
        break case catch continue default defer do else fallthrough for guard if in repeat return throw
        switch where while Any as await false is nil self Self super throws true try Type Protocol some any
        """
        .split(whereSeparator: \.isWhitespace).map(String.init))

    /// Names the generated code or the macro uses in a message, which a field must not take.
    static let reservedMembers: Set<String> = ["unknownFields", "CodingKeys"]

    /// `a_int32` → `aInt32` (lower) or `AInt32` (upper); a component after an underscore starts upper case.
    static func camel(_ name: String, upper: Bool) -> String {
        var result = ""
        var capitalizeNext = upper
        for character in name {
            if character == "_" {
                capitalizeNext = !result.isEmpty || upper
                continue
            }
            if capitalizeNext {
                result += character.uppercased()
                capitalizeNext = false
            } else {
                result.append(character)
            }
        }
        if !upper, let first = result.first { result = first.lowercased() + result.dropFirst() }
        return result
    }

    /// The prefix of a top-level type in `package`: `protobuf_test_messages.proto3` → `ProtobufTestMessages_Proto3_`.
    static func prefix(package: String) -> String {
        guard !package.isEmpty else { return "" }
        return package.split(separator: ".").map { camel(String($0), upper: true) }.joined(separator: "_") + "_"
    }

    /// A property name, escaped when it is a keyword, renamed when the generated code needs it.
    static func property(_ fieldName: String) -> String {
        escape(avoidingReserved(camel(fieldName, upper: false)))
    }

    /// An enumeration case: the value's name in lower camel case, without `ENUMNAME_` in front when the rest stands alone.
    static func enumCase(_ valueName: String, enumName: String) -> String {
        let prefix = upperSnake(enumName) + "_"
        var name = valueName
        if name.hasPrefix(prefix), let next = name.dropFirst(prefix.count).first, !next.isNumber {
            name = String(name.dropFirst(prefix.count))
        }
        return escape(camel(name.lowercased(), upper: false))
    }

    static func escape(_ name: String) -> String { keywords.contains(name) ? "`\(name)`" : name }

    static func avoidingReserved(_ name: String) -> String { reservedMembers.contains(name) ? name + "_" : name }

    /// `ForeignEnum` → `FOREIGN_ENUM`.
    static func upperSnake(_ name: String) -> String {
        var result = ""
        for (index, character) in name.enumerated() {
            if character.isUppercase, index > 0 { result += "_" }
            result += character.uppercased()
        }
        return result
    }
}
