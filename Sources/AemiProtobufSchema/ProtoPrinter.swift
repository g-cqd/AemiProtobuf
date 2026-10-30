/// Writes a file descriptor as `.proto` source that compiles back to the same descriptor (roadmap 0002): proto2, proto3 or
/// editions; groups and maps in their own syntax; options, custom ones included, as `name = value` (sub-messages as dotted
/// paths, repeated messages as text-format literals); every type name fully qualified. Iterative over nested messages.
///
/// Custom options are found in the file itself and in `dependencies`; an option extension declared nowhere they can see is left
/// out.
public struct ProtoPrinter: Sendable {
    let dependencies: [FileDescriptor]

    public init(dependencies: [FileDescriptor] = []) { self.dependencies = dependencies }

    public func print(_ file: FileDescriptor) -> String {
        var files = dependencies.filter { $0.name != file.name && $0.name != "google/protobuf/descriptor.proto" }
        files.append(file)
        files.insert(contentsOf: EmbeddedBase64.descriptorProto, at: 0)
        var writer = ProtoSourceWriter(file: file, schema: DynamicSchema(FileDescriptorSet(files: files)))
        return writer.run()
    }
}
