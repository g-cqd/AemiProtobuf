/// A type with a protobuf definition (roadmap 0005).
public protocol AemiProtoDefined {
    static var protoName: String { get }
    static var protoDefinition: String { get }
    static var protoDependencies: [Any.Type] { get }
}
