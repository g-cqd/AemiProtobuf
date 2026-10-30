/// The edition features in force for a declaration: the edition's defaults, then the file's, every enclosing message's, and
/// the declaration's own (roadmap 0028). proto2 and proto3 files have the defaults of `EDITION_PROTO2` and `EDITION_PROTO3`.
public struct ResolvedFeatures: Sendable, Equatable {
    public var fieldPresence: Int32  // EXPLICIT 1, IMPLICIT 2, LEGACY_REQUIRED 3
    public var enumType: Int32  // OPEN 1, CLOSED 2
    public var repeatedFieldEncoding: Int32  // PACKED 1, EXPANDED 2
    public var utf8Validation: Int32  // VERIFY 2, NONE 3
    public var messageEncoding: Int32  // LENGTH_PREFIXED 1, DELIMITED 2

    public static let proto2 = Self(
        fieldPresence: 1, enumType: 2, repeatedFieldEncoding: 2, utf8Validation: 3, messageEncoding: 1)
    public static let proto3 = Self(
        fieldPresence: 2, enumType: 1, repeatedFieldEncoding: 1, utf8Validation: 2, messageEncoding: 1)
    public static let edition2023 = Self(
        fieldPresence: 1, enumType: 1, repeatedFieldEncoding: 1, utf8Validation: 2, messageEncoding: 1)

    /// The defaults of `file`'s syntax or edition, then its own features.
    public static func of(_ file: FileDescriptor) -> Self {
        let defaults: Self =
            switch file.resolvedSyntax {
                case "proto3": .proto3
                case "editions": .edition2023
                default: .proto2
            }
        return defaults.merged(file.features)
    }

    public func merged(_ features: FeatureSet?) -> Self {
        guard let features else { return self }
        var result = self
        if let value = features.fieldPresence { result.fieldPresence = value }
        if let value = features.enumType { result.enumType = value }
        if let value = features.repeatedFieldEncoding { result.repeatedFieldEncoding = value }
        if let value = features.utf8Validation { result.utf8Validation = value }
        if let value = features.messageEncoding { result.messageEncoding = value }
        return result
    }
}
