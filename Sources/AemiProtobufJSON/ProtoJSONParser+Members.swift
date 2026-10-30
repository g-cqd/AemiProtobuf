import AemiJSONCore
import AemiProtobufSchema

extension ProtoJSONParser {
    /// Reads an object's members as fields, by JSON name or declared name. A field named twice, or a second member of a oneof,
    /// is refused; `null` is an absent field, except for a `google.protobuf.Value` or `NullValue` field.
    mutating func readMembers(_ job: Job) throws(ProtoJSONError) {
        let node = job.node
        let type = nodes[node].type
        var seen = SeenFields()
        var oneofs = SeenFields()
        for (key, json) in JSONShape.members(of: job.json) {
            if job.skipsType && key == "@type" { continue }
            guard let field = type.field(named: key) else {
                if options.ignoreUnknownFields { continue }
                throw .unknownField(message: type.name, name: key)
            }
            do throws(ProtoJSONError) {
                guard seen.insert(Int(field.number)) else { throw .invalid("the field is named twice", path: "") }
                let shape = JSONShape(json)
                if case .null = shape, field.isRepeated || !Self.takesNull(field.typeName) { continue }
                if let oneof = field.oneofIndex, !oneofs.insert(oneof) {
                    throw .invalid("a second member of the oneof", path: "")
                }
                try readField(field, json, shape, node)
            } catch {
                throw locate(error, node, field.name)
            }
        }
    }

    private mutating func readField(_ field: DynamicField, _ json: JSON, _ shape: JSONShape, _ node: Int)
        throws(ProtoJSONError)
    {
        if let entry = field.mapEntry {
            try readMap(field, entry, json, shape, node)
        } else if field.isRepeated {
            try readList(field, json, shape, node)
        } else if field.type == .message || field.type == .group {
            try spawn(
                field.typeName, json, Link(parent: node, field: field.number, slot: .place(.single)), name: field.name)
        } else if let value = try element(shape, field.type, field.typeName) {
            if field.hasPresence || !value.isImplicitDefault { nodes[node].fields.values[field.number] = value }
        }
    }

    /// Whether `null` is a value of the type, not an absent field.
    static func takesNull(_ typeName: String?) -> Bool {
        typeName == WellKnownType.valueType || typeName == WellKnownType.nullValue
    }

    /// One scalar: `null` is `NULL_VALUE` for a `NullValue` and refused otherwise; `nil` for an ignored enumeration name.
    func element(_ shape: JSONShape, _ type: FieldType, _ typeName: String?) throws(ProtoJSONError) -> DynamicValue? {
        if case .null = shape {
            guard typeName == WellKnownType.nullValue else { throw .invalid("null is not a value here", path: "") }
            return .enumeration(0)
        }
        return try scalars.value(shape, type, typeName: typeName, path: "")
    }

    private mutating func readList(_ field: DynamicField, _ json: JSON, _ shape: JSONShape, _ node: Int)
        throws(ProtoJSONError)
    {
        guard case .array = shape else { throw .invalid("not an array", path: "") }
        let isMessage = field.type == .message || field.type == .group
        let elements = JSONShape.elements(of: json)
        var values: [DynamicValue] = []
        values.reserveCapacity(elements.count)
        for item in elements {
            let itemShape = JSONShape(item)
            if isMessage {
                if case .null = itemShape, field.typeName != WellKnownType.valueType {
                    throw .invalid("null in a repeated field", path: "")
                }
                values.append(.message(DynamicMessage(typeName: field.typeName ?? "")))
                let link = Link(parent: node, field: field.number, slot: .place(.element(values.count - 1)))
                try spawn(field.typeName, item, link, name: field.name)
            } else if let value = try element(itemShape, field.type, field.typeName) {
                values.append(value)
            }
        }
        nodes[node].fields.lists[field.number] = values
    }

    private mutating func readMap(
        _ field: DynamicField, _ entry: DynamicField.MapEntry, _ json: JSON, _ shape: JSONShape, _ node: Int
    ) throws(ProtoJSONError) {
        guard case .object = shape else { throw .invalid("not an object", path: "") }
        var map: [DynamicValue: DynamicValue] = [:]
        for (text, item) in JSONShape.members(of: json) {
            let key = try scalars.key(text, entry.key.type, path: "")
            guard map[key] == nil else { throw .invalid("map key \(text) appears twice", path: "") }
            let itemShape = JSONShape(item)
            if entry.value.type == .message {
                if case .null = itemShape, entry.valueTypeName != WellKnownType.valueType {
                    throw .invalid("null as a map value", path: "")
                }
                map[key] = .message(DynamicMessage(typeName: entry.valueTypeName ?? ""))
                let link = Link(parent: node, field: field.number, slot: .place(.mapValue(key)))
                try spawn(entry.valueTypeName, item, link, name: field.name)
            } else if let value = try element(itemShape, entry.value.type, entry.valueTypeName) {
                map[key] = value
            }
        }
        nodes[node].fields.maps[field.number] = map
    }
}
