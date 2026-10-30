/// The message types whose JSON form is not an object of their fields.
enum WellKnownType {
    case any, timestamp, duration, fieldMask, structure, value, listValue, wrapper

    init?(_ name: String) {
        switch name {
            case "google.protobuf.Any": self = .any
            case "google.protobuf.Timestamp": self = .timestamp
            case "google.protobuf.Duration": self = .duration
            case "google.protobuf.FieldMask": self = .fieldMask
            case "google.protobuf.Struct": self = .structure
            case "google.protobuf.Value": self = .value
            case "google.protobuf.ListValue": self = .listValue
            case "google.protobuf.DoubleValue", "google.protobuf.FloatValue", "google.protobuf.Int64Value",
                "google.protobuf.UInt64Value", "google.protobuf.Int32Value", "google.protobuf.UInt32Value",
                "google.protobuf.BoolValue", "google.protobuf.StringValue", "google.protobuf.BytesValue":
                self = .wrapper
            default: return nil
        }
    }

    /// Whether an `Any` holds the type's JSON under `value`: every type above. Empty is an object of no fields, so an `Any` of
    /// it is `{"@type": …}` alone, as C++ writes it (`json/internal/descriptor_traits.h` does not count Empty).
    static func hasJSONForm(_ name: String) -> Bool { WellKnownType(name) != nil }

    static let nullValue = "google.protobuf.NullValue"
    static let valueType = "google.protobuf.Value"
}
