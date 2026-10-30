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
        // A tag no declared field takes is offered to each oneof before it is unknown.
        let unknownTarget = keepsUnknown ? "&self.unknownFields" : "&__discarded"
        let oneofs = fields.filter { $0.shape == .oneof }
            .map {
                "if try \($0.swiftType).__aepbDecodeField(tag, from: &r, into: &self.\($0.name), unknown: \(unknownTarget)) { break }"
            }
        let scratch = !keepsUnknown && !oneofs.isEmpty ? "var __discarded = UnknownFields()\n" : ""
        let fallback = (oneofs + [other]).joined(separator: "\n")
        return """
            mutating func __aepbMerge(from r: inout WireReader) throws(WireError) {
            \(scratch)while let tag = try r.nextTag() {
            switch (tag.fieldNumber.rawValue, tag.wireType) {
            \(cases)
            default:
            \(fallback)
            }
            }
            }
            """
    }

    /// Integer keys equal to the field numbers. A message with no field has a key type with no case and no raw type: an
    /// enumeration with no case cannot declare one.
    static func codingKeys(_ fields: [ProtoFieldSpec]) -> String {
        guard !fields.isEmpty else { return "enum CodingKeys: CodingKey {}" }
        let cases = fields.map { "case \($0.name) = \($0.number)" }.joined(separator: "\n")
        return "enum CodingKeys: Int, CodingKey {\n\(cases)\n}"
    }

    // MARK: Encode

    private static func encodeField(_ f: ProtoFieldSpec) -> String {
        let scalar = ProtoFieldScalar(kind: f.kind, swiftType: f.swiftType)
        switch f.shape {
            case .oneof: return "if let __o = self.\(f.name) { try __o.__aepbEncode(into: &w) }"
            case .map: return mapEncode(f)
            case .single:
                if f.kind == .message {
                    return
                        "try w.appendNonEmptyMessage(field: \(f.number)) { w throws(WireError) in try self.\(f.name).__aepbEncode(into: &w) }"
                }
                return "if \(scalar.isSet("self.\(f.name)")) {\n\(record(f, scalar, "self.\(f.name)"))\n}"
            case .optional:
                return "if let __v = self.\(f.name) {\n\(whole(f, scalar, "__v"))\n}"
            case .repeated where f.kind == .string && f.swiftType == "String":
                return "w.appendRepeatedStrings(field: \(f.number), self.\(f.name))"
            case .repeated where f.kind == .bytes && f.swiftType == "[UInt8]":
                return "w.appendRepeatedBytes(field: \(f.number), self.\(f.name))"
            case .repeated where !f.packed:
                return "for __e in self.\(f.name) {\n\(whole(f, scalar, "__e"))\n}"
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
                return "for __e in self.\(f.name) {\n\(whole(f, scalar, "__e"))\n}"
        }
    }

    /// One whole field of `value`: a group between its tags, a message with its length, or a tagged scalar.
    private static func whole(_ f: ProtoFieldSpec, _ scalar: ProtoFieldScalar, _ value: String) -> String {
        switch f.kind {
            case .group: group(f.number, value)
            case .message: message(f.number, value)
            default: record(f, scalar, value)
        }
    }

    /// A whole tagged field of a non-message value.
    private static func record(_ f: ProtoFieldSpec, _ scalar: ProtoFieldScalar, _ value: String) -> String {
        "w.appendTag(\(f.number), \(f.kind.wireType))\n\(scalar.write(value))"
    }

    private static func group(_ number: Int, _ value: String) -> String {
        "try w.appendGroup(field: \(number)) { w throws(WireError) in try \(value).__aepbEncode(into: &w) }"
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
            case .oneof: return []
            case .map: return [mapDecode(f, keepsUnknown: keepsUnknown)]
            // A message given again merges into the one already read (the encoding guide's merge); a scalar's last wins.
            case .single where f.kind == .message:
                return [
                    "case (\(f.number), \(wire)): try r.readMessage { r throws(WireError) in try self.\(f.name).__aepbMerge(from: &r) }"
                ]
            case .optional where f.kind.isMessage:
                let read = f.kind == .group ? "r.readGroup(tag)" : "r.readMessage"
                return [
                    """
                    case (\(f.number), \(wire)):
                    var __m = self.\(f.name) ?? \(f.swiftType)()
                    self.\(f.name) = nil
                    try \(read) { r throws(WireError) in try __m.__aepbMerge(from: &r) }
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

    // MARK: Required fields

    /// `__aepbMissingRequired()`: the absent required fields, then every nested message, in declaration order. Nil when the
    /// type has neither, so the protocol's default (no required field) applies.
    static func missingRequired(_ fields: [ProtoFieldSpec]) -> String? {
        var checks: [String] = []
        for f in fields {
            let name = f.plainName
            if f.required { checks.append("if self.\(f.name) == nil { return [\"\(name)\"] }") }
            switch f.shape {
                case .oneof:
                    checks.append("if let __p = self.\(f.name)?.__aepbMissingRequired() { return [\"\(name)\"] + __p }")
                case .single where f.kind.isMessage:
                    checks.append("if let __p = self.\(f.name).__aepbMissingRequired() { return [\"\(name)\"] + __p }")
                case .optional where f.kind.isMessage:
                    checks.append("if let __p = self.\(f.name)?.__aepbMissingRequired() { return [\"\(name)\"] + __p }")
                case .repeated where f.kind.isMessage, .map where f.kind.isMessage:
                    checks.append("if let __p = self.\(f.name).__aepbMissingRequired() { return [\"\(name)\"] + __p }")
                default: continue
            }
        }
        guard !checks.isEmpty else { return nil }
        return "func __aepbMissingRequired() -> [String]? {\n" + checks.joined(separator: "\n") + "\nreturn nil\n}"
    }
}
