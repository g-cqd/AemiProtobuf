public struct FileDescriptorSet: Sendable, Equatable {
    public var files: [FileDescriptor]

    public init(files: [FileDescriptor] = []) {
        self.files = files
    }
}
