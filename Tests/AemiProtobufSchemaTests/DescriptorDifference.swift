@testable import AemiProtobufSchema

/// Where two file descriptors first differ, for a readable failure.
enum DescriptorDifference {
    static func first(_ a: FileDescriptor, _ b: FileDescriptor) -> String {
        if a.package != b.package || a.syntax != b.syntax || a.edition != b.edition { return "header" }
        if a.dependencies != b.dependencies || a.publicDependencies != b.publicDependencies { return "dependencies" }
        if a.options != b.options { return "file options \(a.options ?? []) vs \(b.options ?? [])" }
        var pending = Array(zip(a.messages, b.messages))
        if a.messages.count != b.messages.count { return "message count" }
        while let (x, y) = pending.popLast() {
            if x.name != y.name { return "message \(x.name) vs \(y.name)" }
            for (f, g) in zip(x.fields, y.fields) where f != g { return "field \(x.name).\(f.name): \(f) vs \(g)" }
            if x.fields.count != y.fields.count {
                return "\(x.name) field count \(x.fields.count) vs \(y.fields.count)"
            }
            if x.options != y.options { return "\(x.name) options \(x.options ?? []) vs \(y.options ?? [])" }
            if x.nestedMessages.count != y.nestedMessages.count { return "\(x.name) nested count" }
            if x.nestedEnums != y.nestedEnums { return "\(x.name) enums" }
            if x != y { return "\(x.name): \(x) vs \(y)" }
            pending += zip(x.nestedMessages, y.nestedMessages)
        }
        if a.enums != b.enums { return "enums \(a.enums) vs \(b.enums)" }
        if a.services != b.services { return "services \(a.services) vs \(b.services)" }
        if a.extensions != b.extensions { return "extensions \(a.extensions) vs \(b.extensions)" }
        return "elsewhere"
    }
}
