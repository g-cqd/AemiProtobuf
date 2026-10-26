/// The Swift source of the generated members, from the fields.
enum ProtoMessageCodegen {
    static func encode(_ fields: [ProtoFieldSpec]) -> String {
        let body = fields.map(encodeField).joined(separator: "\n")
        return "func __aepbEncode(into w: inout WireWriter) throws(WireError) {\n\(body)\n}"
    }

    static func decode(_ fields: [ProtoFieldSpec]) -> String {
        let cases = fields.flatMap(decodeCases).joined(separator: "\n")
        return """
            static func __aepbDecode(from r: inout WireReader) throws(WireError) -> Self {
            var result = Self()
            while let tag = try r.nextTag() {
            switch (tag.fieldNumber.rawValue, tag.wireType) {
            \(cases)
            default: try r.skipField(tag)
            }
            }
            return result
            }
            """
    }

    static func codingKeys(_ fields: [ProtoFieldSpec]) -> String {
        let cases = fields.map { "case \($0.name) = \($0.number)" }.joined(separator: "\n")
        return "enum CodingKeys: Int, CodingKey {\n\(cases)\n}"
    }

    // MARK: Encode

    private static func encodeField(_ f: ProtoFieldSpec) -> String {
        let scalar = ProtoFieldScalar(kind: f.kind, swiftType: f.swiftType)
        switch f.shape {
            case .single:
                if f.kind == .message { return message(f.number, "self.\(f.name)") }
                return "if \(scalar.isSet("self.\(f.name)")) {\n\(record(f, scalar, "self.\(f.name)"))\n}"
            case .optional:
                let inner = f.kind == .message ? message(f.number, "__v") : record(f, scalar, "__v")
                return "if let __v = self.\(f.name) {\n\(inner)\n}"
            case .repeated:
                if scalar.isBulkCopyable {
                    return "w.appendPackedLittleEndian(field: \(f.number), self.\(f.name))"
                }
                if let encoding = scalar.bulkVarintEncoding {
                    return "w.appendPackedVarints(field: \(f.number), self.\(f.name)\(encoding))"
                }
                if f.kind.isPackable {
                    return """
                        if !self.\(f.name).isEmpty {
                        w.reserve(additional: self.\(f.name).count + 6)
                        try w.appendMessage(field: \(f.number)) { w throws(WireError) in
                        for __e in self.\(f.name) { \(scalar.write("__e")) }
                        }
                        }
                        """
                }
                let element = f.kind == .message ? message(f.number, "__e") : record(f, scalar, "__e")
                return "for __e in self.\(f.name) {\n\(element)\n}"
        }
    }

    /// A whole tagged field of a non-message value.
    private static func record(_ f: ProtoFieldSpec, _ scalar: ProtoFieldScalar, _ value: String) -> String {
        "w.appendTag(\(f.number), \(f.kind.wireType))\n\(scalar.write(value))"
    }

    private static func message(_ number: Int, _ value: String) -> String {
        "try w.appendMessage(field: \(number)) { w throws(WireError) in try \(value).__aepbEncode(into: &w) }"
    }

    // MARK: Decode

    private static func decodeCases(_ f: ProtoFieldSpec) -> [String] {
        let scalar = ProtoFieldScalar(kind: f.kind, swiftType: f.swiftType)
        let wire = f.kind.wireType
        switch f.shape {
            case .single, .optional:
                return ["case (\(f.number), \(wire)): \(assign("result.\(f.name)", scalar))"]
            case .repeated:
                guard f.kind.isPackable else {
                    return ["case (\(f.number), \(wire)): \(append("result.\(f.name)", scalar))"]
                }
                // A repeated number is read packed or unpacked, whichever the writer chose, or both. A packed run adds no level of
                // nesting, and its element count is known before the first element is read.
                let bulk: String? =
                    scalar.isBulkCopyable
                    ? "try r.readPackedLittleEndian(\(f.swiftType).self)"
                    : scalar.bulkVarintEncoding.map { "try r.readPackedVarints(\(f.swiftType).self\($0))" }
                let packed =
                    bulk.map { "case (\(f.number), .lengthDelimited): result.\(f.name).append(contentsOf: \($0))" }
                        ?? """
                        case (\(f.number), .lengthDelimited):
                        try r.readPayload { r throws(WireError) in
                        result.\(f.name).reserveCapacity(result.\(f.name).count + r.remainingVarintCount)
                        while !r.isAtEnd { \(append("result.\(f.name)", scalar)) }
                        }
                        """
                return [
                    packed,
                    "case (\(f.number), \(wire)): \(append("result.\(f.name)", scalar))"
                ]
        }
    }

    private static func assign(_ target: String, _ scalar: ProtoFieldScalar) -> String {
        scalar.readsOptionalValue ? "if let __v = \(scalar.read) { \(target) = __v }" : "\(target) = \(scalar.read)"
    }

    private static func append(_ target: String, _ scalar: ProtoFieldScalar) -> String {
        scalar.readsOptionalValue
            ? "if let __v = \(scalar.read) { \(target).append(__v) }" : "\(target).append(\(scalar.read))"
    }
}
