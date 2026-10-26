/// Protobuf field labels as defined in `google.protobuf.FieldDescriptorProto.Label`.
public enum FieldLabel: Int32, Sendable, Equatable, Hashable {
    case `optional` = 1
    case `required` = 2
    case `repeated` = 3
}
