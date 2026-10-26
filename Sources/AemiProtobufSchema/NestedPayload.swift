/// A message-typed field's payload, found while checking its parent.
struct NestedPayload {
    let field: FieldDescriptor
    let range: Range<Int>
    /// Which occurrence of the field this is, counting from 0.
    let index: Int
}
