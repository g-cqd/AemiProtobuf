import AemiJSONCore

/// What a JSON value is, read once: the parser decides every field by it.
enum JSONShape {
    case null
    case bool(Bool)
    /// The number's exact text, so 64-bit integers are read without passing through a `Double`.
    case number(String)
    case string(String)
    case object
    case array

    init(_ json: JSON) {
        if json.isNull {
            self = .null
        } else if let value = json.bool {
            self = .bool(value)
        } else if json.isObject {
            self = .object
        } else if json.isArray {
            self = .array
        } else if let lexeme = json.numberLexeme {
            self = .number(lexeme)
        } else {
            self = .string(json.string ?? "")
        }
    }

    /// The members of an object in document order, duplicates included.
    static func members(of json: JSON) -> [(String, JSON)] {
        var members: [(String, JSON)] = []
        members.reserveCapacity(json.count)
        json.forEachMember { members.append(($0, $1)) }
        return members
    }

    /// The elements of an array in order.
    static func elements(of json: JSON) -> [JSON] { json.array ?? [] }
}
