public import AemiProtobufCore

/// A message's fields while it is being assembled, for readers that build nested messages without recursion (the binary
/// decoder and the JSON reader): repeated fields and maps are kept apart so they grow in place, and nested messages are placed
/// once they are complete.
public struct DynamicFields: Sendable {
    public var values: [Int32: DynamicValue] = [:]
    public var lists: [Int32: [DynamicValue]] = [:]
    public var maps: [Int32: [DynamicValue: DynamicValue]] = [:]
    public var unknown = UnknownFields()

    public init() {}

    /// Puts a complete nested message where `slot` says in `field`.
    public mutating func place(_ message: DynamicMessage, field: Int32, slot: DynamicSlot) {
        switch slot {
            case .single: values[field] = .message(message)
            case .element(let position): lists[field, default: []][position] = .message(message)
            case .mapValue(let key): maps[field, default: [:]][key] = .message(message)
        }
    }

    /// The message, its storage handed over: the dictionaries are taken out first, so they are unique and grow in place.
    public mutating func take(typeName: String) -> DynamicMessage {
        var fields = values
        values = [:]
        let lists = self.lists
        self.lists = [:]
        let maps = self.maps
        self.maps = [:]
        for (number, items) in lists { fields[number] = .list(items) }
        for (number, entries) in maps { fields[number] = .map(entries) }
        return DynamicMessage(typeName: typeName, fields: fields, unknownFields: unknown)
    }
}
