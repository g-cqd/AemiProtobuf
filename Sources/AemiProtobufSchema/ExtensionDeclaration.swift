/// An extension with where it was declared: the scope its name and its type names resolve in (the package, or the enclosing
/// message), and the features in force there.
struct ExtensionDeclaration {
    let scope: String
    let field: FieldDescriptor
    let features: ResolvedFeatures

    /// The extension's fully qualified name, as JSON writes it between brackets.
    var fullName: String { scope.isEmpty ? field.name : scope + "." + field.name }
}
