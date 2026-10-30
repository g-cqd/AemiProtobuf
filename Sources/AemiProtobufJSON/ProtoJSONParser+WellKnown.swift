import AemiJSONCore
import AemiProtobufSchema

extension ProtoJSONParser {
    /// Reads the JSON form of a well-known type: a string for Timestamp, Duration and FieldMask, the bare value for a wrapper,
    /// any JSON for Struct, Value and ListValue, and an object with `@type` for Any.
    mutating func readWellKnown(_ kind: WellKnownType, _ job: Job) throws(ProtoJSONError) {
        let node = job.node
        let shape = JSONShape(job.json)
        switch kind {
            case .timestamp, .duration:
                guard case .string(let text) = shape,
                    let (seconds, nanos) = kind == .timestamp
                        ? ProtoJSONTime.timestamp(text) : ProtoJSONTime.duration(text)
                else { throw .invalid("not a valid \(kind == .timestamp ? "Timestamp" : "Duration")", path: "") }
                if seconds != 0 { nodes[node].fields.values[1] = .int64(seconds) }
                if nanos != 0 { nodes[node].fields.values[2] = .int32(nanos) }
            case .fieldMask:
                guard case .string(let text) = shape else { throw .invalid("a FieldMask is a string", path: "") }
                var paths: [DynamicValue] = []
                for part in text.split(separator: ",", omittingEmptySubsequences: false) where !text.isEmpty {
                    guard let snake = ProtoJSONPaths.snake(String(part)) else {
                        throw .invalid("\(part) is not a lowerCamel path", path: "")
                    }
                    paths.append(.string(snake))
                }
                if !paths.isEmpty { nodes[node].fields.lists[1] = paths }
            case .wrapper:
                guard let field = nodes[node].type.field(number: 1) else {
                    throw .invalid("a wrapper without value", path: "")
                }
                if case .null = shape { throw .invalid("null is not a value here", path: "") }
                if let value = try scalars.value(shape, field.type, typeName: nil, path: ""), !value.isImplicitDefault {
                    nodes[node].fields.values[1] = value
                }
            case .structure:
                guard case .object = shape else { throw .invalid("a Struct is an object", path: "") }
                try readStruct(job.json, node)
            case .value: try readValue(shape, job.json, node)
            case .listValue:
                guard case .array = shape else { throw .invalid("a ListValue is an array", path: "") }
                try readListValue(job.json, node)
            case .any: try readAny(shape, job.json, node)
        }
    }

    private mutating func readStruct(_ json: JSON, _ node: Int) throws(ProtoJSONError) {
        var map: [DynamicValue: DynamicValue] = [:]
        for (key, item) in JSONShape.members(of: json) {
            guard map[.string(key)] == nil else { throw .invalid("\(key) appears twice", path: "") }
            map[.string(key)] = .message(DynamicMessage(typeName: WellKnownType.valueType))
            try spawn(
                WellKnownType.valueType, item, Link(parent: node, field: 1, slot: .place(.mapValue(.string(key)))),
                name: key)
        }
        nodes[node].fields.maps[1] = map
    }

    private mutating func readValue(_ shape: JSONShape, _ json: JSON, _ node: Int)
        throws(ProtoJSONError)
    {
        switch shape {
            case .null: nodes[node].fields.values[1] = .enumeration(0)
            case .number(let text):
                guard let value = ProtoJSONNumber.double(text, quoted: false) else {
                    throw .invalid("\(text) is out of range", path: "")
                }
                nodes[node].fields.values[2] = .double(value)
            case .string(let text): nodes[node].fields.values[3] = .string(text)
            case .bool(let value): nodes[node].fields.values[4] = .bool(value)
            case .object:
                try spawn(
                    "google.protobuf.Struct", json, Link(parent: node, field: 5, slot: .place(.single)),
                    name: "structValue")
            case .array:
                try spawn(
                    "google.protobuf.ListValue", json, Link(parent: node, field: 6, slot: .place(.single)),
                    name: "listValue")
        }
    }

    private mutating func readListValue(_ json: JSON, _ node: Int) throws(ProtoJSONError) {
        var values: [DynamicValue] = []
        for item in JSONShape.elements(of: json) {
            values.append(.message(DynamicMessage(typeName: WellKnownType.valueType)))
            try spawn(
                WellKnownType.valueType, item, Link(parent: node, field: 1, slot: .place(.element(values.count - 1))),
                name: "values")
        }
        nodes[node].fields.lists[1] = values
    }

    /// `{}` is an empty Any. Otherwise `@type` names the message; a well-known type's JSON form is under `value` (absent for its
    /// default), any other message's fields are the object's other members.
    private mutating func readAny(_ shape: JSONShape, _ json: JSON, _ node: Int) throws(ProtoJSONError) {
        guard case .object = shape else { throw .invalid("an Any is an object", path: "") }
        let members = JSONShape.members(of: json)
        guard !members.isEmpty else { return }
        guard let typeMember = members.first(where: { $0.0 == "@type" }),
            case .string(let url) = JSONShape(typeMember.1),
            let slash = url.lastIndex(of: "/")
        else { throw .invalid("an Any needs @type, a type URL", path: "") }
        let name = String(url[url.index(after: slash)...])
        guard schema.messageType(named: name) != nil else { throw .unknownType(name) }
        let link = Link(parent: node, field: 2, slot: .anyValue(typeURL: url))
        guard WellKnownType.hasJSONForm(name) else {
            try spawn(name, json, link, name: "value", skipsType: true)
            return
        }
        guard members.allSatisfy({ $0.0 == "@type" || $0.0 == "value" }) else {
            throw .invalid("an Any of \(name) holds only @type and value", path: "")
        }
        // No `value` is the type's default message, whose encoding is empty.
        guard let value = members.first(where: { $0.0 == "value" })?.1 else {
            nodes[node].fields.values[1] = .string(url)
            return
        }
        try spawn(name, value, link, name: "value")
    }
}
