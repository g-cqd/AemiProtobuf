import AemiProtobufCore

/// Reads a field out of a raw options message: the last occurrence of a scalar, as a decoder would keep it; every occurrence of a
/// `FeatureSet`, merged. A malformed options message reads as one that sets nothing; it came from protoc, which does not write one.
enum OptionsReader {
    static func varint(_ options: [UInt8]?, _ number: FieldNumber) -> UInt64? {
        scan(options, number, .varint) { (found: UInt64?, r) throws(WireError) in try r.readVarint() }
    }

    static func flag(_ options: [UInt8]?, _ number: FieldNumber) -> Bool? {
        varint(options, number).map { $0 != 0 }
    }

    static func features(_ options: [UInt8]?, _ number: FieldNumber) -> FeatureSet? {
        scan(options, number, .lengthDelimited) { (found: FeatureSet?, r) throws(WireError) in
            var features = found ?? FeatureSet()
            try features.merge(bytes: try r.readBytes())
            return features
        }
    }

    /// Folds every occurrence of field `number` with wire type `type` through `read`, skipping the rest.
    private static func scan<T>(
        _ options: [UInt8]?, _ number: FieldNumber, _ type: WireType,
        _ read: (T?, inout WireReader) throws(WireError) -> T
    ) -> T? {
        guard let options else { return nil }
        let found = try? WireReader.withReader(over: options) { r throws(WireError) -> T? in
            var found: T?
            while let tag = try r.nextTag() {
                if tag.fieldNumber == number, tag.wireType == type {
                    found = try read(found, &r)
                } else {
                    try r.skipField(tag)
                }
            }
            return found
        }
        return found ?? nil
    }
}
