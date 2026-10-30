/// Compiles `.proto` files to descriptors as protoc does (roadmap 0002): imports, name resolution, options (custom ones
/// included), default values, the checks protoc makes, proto2, proto3 and editions. The result is what
/// `protoc --include_imports --descriptor_set_out` writes: every file, each after the files it imports.
///
/// Files are read through `load`, by the path an import names; nothing touches the file system. Parsing, resolution and every
/// later pass are loops over flat lists, so nesting is bounded by the parser's depth limit (100 declarations) and never by the stack.
public struct ProtoCompiler: Sendable {
    public typealias Loader = @Sendable (String) -> String?
    let load: Loader

    public init(_ load: @escaping Loader) { self.load = load }

    public func compile(_ roots: [String]) throws(ProtoCompileError) -> FileDescriptorSet {
        var parsed = try parseAll(roots)
        var symbols = ProtoSymbols()
        for file in parsed { try ProtoResolver.declare(file, in: &symbols) }
        let resolver = ProtoResolver(symbols: symbols)
        for index in parsed.indices { try resolver.resolve(&parsed[index]) }
        try ProtoDefaults.apply(&parsed)
        try ProtoOptionInterpreter(files: parsed, symbols: symbols).interpret(&parsed)
        let files = parsed.map(ProtoFileBuilder.build)
        try ProtoChecks.check(files, parsed: parsed)
        return FileDescriptorSet(files: files)
    }

    /// Reads the roots and everything they import, each file after its imports (depth first, in import order).
    private func parseAll(_ roots: [String]) throws(ProtoCompileError) -> [ParsedFile] {
        var ordered: [ParsedFile] = []
        var done: Set<String> = []
        var open: [(file: ParsedFile, next: Int)] = []
        var opening: Set<String> = []
        for root in roots where !done.contains(root) {
            open.append((try parse(root, importedBy: nil), 0))
            opening.insert(root)
            while let (file, next) = open.last {
                guard next < file.dependencies.count else {
                    open.removeLast()
                    opening.remove(file.name)
                    done.insert(file.name)
                    ordered.append(file)
                    continue
                }
                open[open.count - 1].next += 1
                let dependency = file.dependencies[next]
                if done.contains(dependency) { continue }
                guard !opening.contains(dependency) else {
                    throw ProtoCompileError(file: file.name, message: "file recursively imports itself: \(dependency)")
                }
                open.append((try parse(dependency, importedBy: file.name), 0))
                opening.insert(dependency)
            }
        }
        return ordered
    }

    private func parse(_ name: String, importedBy: String?) throws(ProtoCompileError) -> ParsedFile {
        guard let text = load(name) else {
            throw ProtoCompileError(
                file: importedBy ?? name,
                message: importedBy == nil ? "file not found" : "import \"\(name)\" was not found")
        }
        var parser = try ProtoFileParser(text, name: name)
        return try parser.parse()
    }
}
