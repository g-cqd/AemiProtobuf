/// `message Repeated { repeated T values = 1; }` for the generic `Codable` path (no fast-path conformance).
public struct RepeatedMessage<Element: Codable>: Codable {
    public var values: [Element]

    enum CodingKeys: Int, CodingKey { case values = 1 }

    public init(_ values: [Element]) { self.values = values }
}
