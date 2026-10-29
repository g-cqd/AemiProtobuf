/// The Swift source of the generated members, from the fields.
enum ProtoMessageCodegen {
    static func encode(_ fields: [ProtoFieldSpec], keepsUnknown: Bool) -> String {
        var body = fields.map(encodeField).joined(separator: "\n")
        if keepsUnknown { body += "\nw.appendUnknownFields(self.unknownFields)" }
        return "func __aepbEncode(into w: inout WireWriter) throws(WireError) {\n\(body)\n}"
    }

    static let decode = """
        static func __aepbDecode(from r: inout WireReader) throws(WireError) -> Self {
        var result = Self()
        try result.__aepbMerge(from: &r)
        return result
        }
        """

    static func merge(_ fields: [ProtoFieldSpec], keepsUnknown: Bool) -> String {
        let cases = fields.flatMap { decodeCases($0, keepsUnknown: keepsUnknown) }.joined(separator: "\n")
        let other = keepsUnknown ? "try r.readUnknownField(tag, into: &self.unknownFields)" : "try r.skipField(tag)"
        return """
            mutating func __aepbMerge(from r: inout WireReader) throws(WireError) {
            while let tag = try r.nextTag() {
            switch (tag.fieldNumber.rawValue, tag.wireType) {
            \(cases)
            default: \(other)
            }
            }
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
            case .map: return mapEncode(f)
            case .single:
                if f.kind == .message {
                    return
                        "try w.appendNonEmptyMessage(field: \(f.number)) { w throws(WireError) in try self.\(f.name).__aepbEncode(into: &w) }"
                }
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

    private static func decodeCases(_ f: ProtoFieldSpec, keepsUnknown: Bool) -> [String] {
        // A closed enumeration's number with no case is kept as an unknown varint field, as C++ keeps it (roadmap 0023).
        let scalar = ProtoFieldScalar(
            kind: f.kind, swiftType: f.swiftType,
            unknown: keepsUnknown
                ? "self.unknownFields.appendVarint(field: \(f.number), UInt64(bitPattern: Int64(__raw)))" : nil)
        let wire = f.kind.wireType
        switch f.shape {
            case .map: return [mapDecode(f, keepsUnknown: keepsUnknown)]
            // A message given again merges into the one already read (the encoding guide's merge); a scalar's last wins.
            case .single where f.kind == .message:
                return [
                    "case (\(f.number), \(wire)): try r.readMessage { r throws(WireError) in try self.\(f.name).__aepbMerge(from: &r) }"
                ]
            case .optional where f.kind == .message:
                return [
                    """
                    case (\(f.number), \(wire)):
                    var __m = self.\(f.name) ?? \(f.swiftType)()
                    self.\(f.name) = nil
                    try r.readMessage { r throws(WireError) in try __m.__aepbMerge(from: &r) }
                    self.\(f.name) = __m
                    """
                ]
            case .single, .optional:
                return ["case (\(f.number), \(wire)): \(assign("self.\(f.name)", scalar))"]
            case .repeated:
                guard f.kind.isPackable else {
                    return ["case (\(f.number), \(wire)): \(append("self.\(f.name)", scalar))"]
                }
                // A repeated number is read packed or unpacked, whichever the writer chose, or both. A packed run adds no level of
                // nesting, and its element count is known before the first element is read.
                let bulk: String? =
                    scalar.isBulkCopyable
                    ? "try r.readPackedLittleEndian(\(f.swiftType).self)"
                    : scalar.bulkVarintEncoding.map { "try r.readPackedVarints(\(f.swiftType).self\($0))" }
                let packed =
                    bulk.map { "case (\(f.number), .lengthDelimited): self.\(f.name).append(contentsOf: \($0))" }
                        ?? """
                        case (\(f.number), .lengthDelimited):
                        try r.readPayload { r throws(WireError) in
                        self.\(f.name).reserveCapacity(self.\(f.name).count + r.remainingVarintCount)
                        while !r.isAtEnd { \(append("self.\(f.name)", scalar)) }
                        }
                        """
                return [
                    packed,
                    "case (\(f.number), \(wire)): \(append("self.\(f.name)", scalar))"
                ]
        }
    }

    private static func assign(_ target: String, _ scalar: ProtoFieldScalar) -> String {
        store(scalar) { "\(target) = \($0)" }
    }

    private static func append(_ target: String, _ scalar: ProtoFieldScalar) -> String {
        store(scalar) { "\(target).append(\($0))" }
    }

    /// `body` applied to the value read. An enumeration's number is read first; with no case for it, it goes where the scalar's
    /// `unknown` says, or nowhere.
    private static func store(_ scalar: ProtoFieldScalar, _ body: (String) -> String) -> String {
        guard scalar.readsOptionalValue else { return body(scalar.read) }
        let otherwise = scalar.unknown.map { " else { \($0) }" } ?? ""
        return "do { let __raw = try r.readInt32(); if let __v = \(scalar.read) { \(body("__v")) }\(otherwise) }"
    }

    // MARK: Maps

    /// Every entry, key and value both written even at their defaults, as C++ writes them; in ``ProtoMap`` order.
    private static func mapEncode(_ f: ProtoFieldSpec) -> String {
        """
        for (__k, __v) in ProtoMap.sorted(self.\(f.name)) {
        try w.appendMessage(field: \(f.number)) { w throws(WireError) in
        \(mapEntryBody(f, value: "__v"))
        }
        }
        """
    }

    private static func mapScalars(
        _ f: ProtoFieldSpec
    ) -> (key: (kind: ProtoKind, swiftType: String), keyScalar: ProtoFieldScalar, valueScalar: ProtoFieldScalar)? {
        guard let key = f.key else { return nil }
        return (
            key, ProtoFieldScalar(kind: key.kind, swiftType: key.swiftType),
            ProtoFieldScalar(kind: f.kind, swiftType: f.swiftType)
        )
    }

    /// `rawEnumeration`: the value is an enumeration's number (`Int32`), not a case.
    private static func mapEntryBody(_ f: ProtoFieldSpec, value: String, rawEnumeration: Bool = false) -> String {
        guard let (key, keyScalar, valueScalar) = mapScalars(f) else { return "" }
        let keyPart = "w.appendTag(1, \(key.kind.wireType))\n\(keyScalar.write("__k"))"
        let valuePart =
            rawEnumeration
            ? "w.appendTag(2, .varint)\nw.appendInt32(\(value))"
            : f.kind == .message
                ? "try w.appendMessage(field: 2) { w throws(WireError) in try \(value).__aepbEncode(into: &w) }"
                : "w.appendTag(2, \(f.kind.wireType))\n\(valueScalar.write(value))"
        return keyPart + "\n" + valuePart
    }

    /// An entry's key and value start at their defaults, take the last occurrence (a message value merges), and other fields
    /// inside the entry are skipped. A closed enumeration value with no case sends the entry to the unknown fields, as C++ does.
    private static func mapDecode(_ f: ProtoFieldSpec, keepsUnknown: Bool) -> String {
        guard let (key, keyScalar, valueScalar) = mapScalars(f) else { return "" }
        let isEnum = f.kind == .enumeration
        let valueDefault = isEnum ? "Int32(0)" : defaultValue(f.kind, f.swiftType)
        let valueRead: String =
            switch f.kind {
                case .message: "try r.readMessage { r throws(WireError) in try __v.__aepbMerge(from: &r) }"
                case .enumeration: "__v = try r.readInt32()"
                default: "__v = \(valueScalar.read)"
            }
        var store = "self.\(f.name)[__k] = __v"
        if isEnum {
            let keep =
                keepsUnknown
                ? """
                 else {
                var __w = WireWriter()
                try __w.appendMessage(field: \(f.number)) { w throws(WireError) in
                \(mapEntryBody(f, value: "__v", rawEnumeration: true))
                }
                self.unknownFields.appendEncoded(__w.bytes)
                }
                """ : ""
            store = "if let __e = ProtoEnumeration.value(\(f.swiftType).self, __v) { self.\(f.name)[__k] = __e }\(keep)"
        }
        return """
            case (\(f.number), .lengthDelimited):
            var __k: \(key.swiftType) = \(defaultValue(key.kind, key.swiftType))
            var __v = \(valueDefault)
            try r.readMessage { r throws(WireError) in
            while let __t = try r.nextTag() {
            switch (__t.fieldNumber.rawValue, __t.wireType) {
            case (1, \(key.kind.wireType)): __k = \(keyScalar.read)
            case (2, \(f.kind.wireType)): \(valueRead)
            default: try r.skipField(__t)
            }
            }
            }
            \(store)
            """
    }

    /// The proto3 default of a value of `kind` spelled `swiftType`, as Swift source.
    private static func defaultValue(_ kind: ProtoKind, _ swiftType: String) -> String {
        switch kind {
            case .bool: "false"
            case .string: "\"\""
            case .bytes: swiftType == "Data" ? "Data()" : "[UInt8]()"
            case .message: "\(swiftType)()"
            case .float, .double: "\(swiftType)(0)"
            default: "\(swiftType)(0)"
        }
    }
}
