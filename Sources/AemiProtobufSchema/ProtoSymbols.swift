/// Every name the compiled files declare, by fully qualified name: what it is and where it was declared. Built before any name
/// is resolved, so it also finds duplicate declarations.
struct ProtoSymbols {
    enum Kind: Equatable {
        case package, message, enumeration, enumValue, service, method, field, oneof, `extension`

        var isType: Bool { self == .message || self == .enumeration }
        var isAggregate: Bool { self == .package || self == .message || self == .enumeration || self == .service }
    }

    private(set) var kinds: [String: Kind] = [:]
    private var files: [String: String] = [:]

    func kind(of name: String) -> Kind? { kinds[name] }

    /// Records a declaration; a second one of the same name is refused (a package may be declared by many files).
    mutating func add(_ name: String, _ kind: Kind, file: String, line: Int, column: Int) throws(ProtoCompileError) {
        if let existing = kinds[name] {
            if existing == .package && kind == .package { return }
            let other = files[name] ?? file
            let place = other == file ? "" : " in file \"\(other)\""
            var message = "\"\(name)\" is already defined\(place)."
            if kind == .enumValue { message += " Note that enum values use C++ scoping rules." }
            throw ProtoCompileError(file: file, line: line, column: column, message: message)
        }
        kinds[name] = kind
        files[name] = file
    }

    /// Adds a package and every prefix of it.
    mutating func addPackage(_ package: String, file: String) throws(ProtoCompileError) {
        guard !package.isEmpty else { return }
        var prefix = ""
        for part in package.split(separator: ".") {
            prefix = prefix.isEmpty ? String(part) : prefix + "." + part
            try add(prefix, .package, file: file, line: 0, column: 0)
        }
    }

    /// The fully qualified name `name` denotes from `scope`, as protoc resolves it: a leading `.` is absolute; otherwise the
    /// first component is looked up from the innermost scope outward (skipping what `accept` refuses when it is the whole
    /// name), and the rest must be found under it.
    func resolve(_ name: String, in scope: String, accept: (Kind) -> Bool) -> String? {
        if name.hasPrefix(".") {
            let absolute = String(name.dropFirst())
            return kinds[absolute].map(accept) == true ? absolute : nil
        }
        let first = name.split(separator: ".", maxSplits: 1).first.map(String.init) ?? name
        let rest = name.count > first.count ? String(name.dropFirst(first.count)) : ""
        var current = scope
        while true {
            let candidate = current.isEmpty ? first : current + "." + first
            if let kind = kinds[candidate] {
                if rest.isEmpty {
                    if accept(kind) { return candidate }
                } else if kind.isAggregate {
                    let full = candidate + rest
                    if let found = kinds[full], accept(found) { return full }
                    return nil
                }
            }
            if current.isEmpty { return nil }
            current = current.lastIndex(of: ".").map { String(current[..<$0]) } ?? ""
        }
    }
}
