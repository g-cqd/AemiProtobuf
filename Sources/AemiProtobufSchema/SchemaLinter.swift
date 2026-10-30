/// Naming and declaration rules for a descriptor set (roadmap 0008): buf's BASIC naming rules and two of its enumeration rules,
/// with buf's reading of each (`BufLintOracleTests` holds a file of violations against `buf lint`), and one rule of its own.
///
/// - `MESSAGE_PASCAL_CASE`, `ENUM_PASCAL_CASE`, `SERVICE_PASCAL_CASE`, `RPC_PASCAL_CASE`: an upper-case first letter and no
///   underscore (`HTTPServer` passes).
/// - `FIELD_LOWER_SNAKE_CASE`, `ONEOF_LOWER_SNAKE_CASE`: no upper-case letter, and no leading, trailing or doubled underscore
///   (digits do not split words: `field1` passes); `PACKAGE_LOWER_SNAKE_CASE` for every package component.
/// - `ENUM_VALUE_UPPER_SNAKE_CASE`: the same, upper case.
/// - `ENUM_NO_ALLOW_ALIAS`, `ENUM_FIRST_VALUE_ZERO`.
/// - `RESERVED_RANGE_HOLDS_FIELD`: a message reserves a number one of its fields uses.
public struct SchemaLinter: Sendable {
    public init() {}

    public func lint(_ set: FileDescriptorSet) -> [LintFinding] {
        var findings: [LintFinding] = []
        func check(_ ok: Bool, _ rule: String, _ name: String, _ what: String) {
            if !ok {
                findings.append(LintFinding(rule: rule, name: name, message: "\(what) \"\(name)\" breaks \(rule)"))
            }
        }
        for file in set.files {
            if !file.package.isEmpty {
                check(
                    file.package.split(separator: ".").allSatisfy { Self.isSnake(String($0), upper: false) },
                    "PACKAGE_LOWER_SNAKE_CASE", file.package, "Package")
            }
            var enums = file.enums
            var pending = file.messages
            while let message = pending.popLast() {
                check(Self.isPascal(message.name), "MESSAGE_PASCAL_CASE", message.name, "Message")
                for field in message.fields where !message.isMapEntry {
                    check(Self.isSnake(field.name, upper: false), "FIELD_LOWER_SNAKE_CASE", field.name, "Field")
                }
                for oneof in message.oneofs where !oneof.name.hasPrefix("_") {
                    check(Self.isSnake(oneof.name, upper: false), "ONEOF_LOWER_SNAKE_CASE", oneof.name, "Oneof")
                }
                for field in message.fields
                where SchemaComparator.isReserved(field.number, message.reservedRanges, endIncluded: false) {
                    check(false, "RESERVED_RANGE_HOLDS_FIELD", field.name, "Field")
                }
                enums += message.nestedEnums
                pending += message.nestedMessages.filter { !$0.isMapEntry }
            }
            for enumeration in enums {
                check(Self.isPascal(enumeration.name), "ENUM_PASCAL_CASE", enumeration.name, "Enum")
                check(!enumeration.allowAlias, "ENUM_NO_ALLOW_ALIAS", enumeration.name, "Enum")
                check(enumeration.values.first?.number == 0, "ENUM_FIRST_VALUE_ZERO", enumeration.name, "Enum")
                for value in enumeration.values {
                    check(
                        Self.isSnake(value.name, upper: true), "ENUM_VALUE_UPPER_SNAKE_CASE", value.name, "Enum value")
                }
            }
            for service in file.services {
                check(Self.isPascal(service.name), "SERVICE_PASCAL_CASE", service.name, "Service")
                for method in service.methods {
                    check(Self.isPascal(method.name), "RPC_PASCAL_CASE", method.name, "RPC")
                }
            }
        }
        return findings
    }

    static func isPascal(_ name: String) -> Bool {
        guard let first = name.first else { return false }
        return first.isUppercase && !name.contains("_")
    }

    static func isSnake(_ name: String, upper: Bool) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("_"), !name.hasSuffix("_"), !name.contains("__") else { return false }
        return !name.contains { upper ? $0.isLowercase : $0.isUppercase }
    }
}
