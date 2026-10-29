/// The generated code of a map field.
extension ProtoMessageCodegen {
    /// Every entry, key and value both written even at their defaults, as C++ writes them; in ``ProtoMap`` order.
    static func mapEncode(_ f: ProtoFieldSpec) -> String {
        """
        for (__k, __v) in ProtoMap.sorted(self.\(f.name)) {
        try w.appendMessage(field: \(f.number)) { w throws(WireError) in
        \(mapEntryBody(f, value: "__v"))
        }
        }
        """
    }

    static func mapScalars(
        _ f: ProtoFieldSpec
    ) -> (key: (kind: ProtoKind, swiftType: String), keyScalar: ProtoFieldScalar, valueScalar: ProtoFieldScalar)? {
        guard let key = f.key else { return nil }
        return (
            key, ProtoFieldScalar(kind: key.kind, swiftType: key.swiftType),
            ProtoFieldScalar(kind: f.kind, swiftType: f.swiftType)
        )
    }

    /// `rawEnumeration`: the value is an enumeration's number (`Int32`), not a case.
    static func mapEntryBody(_ f: ProtoFieldSpec, value: String, rawEnumeration: Bool = false) -> String {
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
    static func mapDecode(_ f: ProtoFieldSpec, keepsUnknown: Bool) -> String {
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
    static func defaultValue(_ kind: ProtoKind, _ swiftType: String) -> String {
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
