/// Where a nested message goes in the message holding it: a singular field, an element of a repeated field, or a map value.
public enum DynamicSlot: Sendable {
    case single
    case element(Int)
    case mapValue(DynamicValue)
}
