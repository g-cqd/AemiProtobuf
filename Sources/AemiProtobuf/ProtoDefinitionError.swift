/// Why definitions could not be assembled into a file.
public enum ProtoDefinitionError: Error, Sendable, Equatable {
    /// A type reached from the roots has no definition: neither a macro message nor an `AemiProtoDefined` enumeration.
    case undefined(String)
    /// Two types declare the same name.
    case duplicateName(String)
}
