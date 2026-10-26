/// Protobuf field types as defined in `google.protobuf.FieldDescriptorProto.Type`.
public enum FieldType: Int32, Sendable, Equatable, Hashable {
    case double = 1
    case float = 2
    case int64 = 3
    case uint64 = 4
    case int32 = 5
    case fixed64 = 6
    case fixed32 = 7
    case bool = 8
    case string = 9
    case group = 10
    case message = 11
    case bytes = 12
    case uint32 = 13
    case `enum` = 14
    case sfixed32 = 15
    case sfixed64 = 16
    case sint32 = 17
    case sint64 = 18
}
