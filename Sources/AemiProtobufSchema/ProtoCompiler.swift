/// Compiles `.proto` files to descriptors as protoc does (roadmap 0002).
public struct ProtoCompiler: Sendable {
    public typealias Loader = @Sendable (String) -> String?
    let load: Loader

    public init(_ load: @escaping Loader) { self.load = load }

    public func compile(_ roots: [String]) throws(ProtoCompileError) -> FileDescriptorSet {
        throw ProtoCompileError(file: roots.first ?? "", message: "not implemented")
    }
}
