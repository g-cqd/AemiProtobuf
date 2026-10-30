import AemiProtobufSchema
import Foundation

// aemi-proto-check: lint a descriptor set, or compare two (roadmap 0008). Descriptor sets come from
// `protoc --include_imports --descriptor_set_out=…`.
//   aemi-proto-check lint set.pb
//   aemi-proto-check breaking old.pb new.pb [--all]     --all also lists changes that do not break the wire
// Exit: 0 nothing found, 1 findings, 2 a usage or input error.

func load(_ path: String) -> FileDescriptorSet {
    do {
        return try FileDescriptorSet.decode(from: [UInt8](try Data(contentsOf: URL(fileURLWithPath: path))))
    } catch {
        FileHandle.standardError.write(Data("aemi-proto-check: cannot read \(path): \(error)\n".utf8))
        exit(2)
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch (arguments.first, arguments.count) {
    case ("lint", 2):
        let findings = SchemaLinter().lint(load(arguments[1]))
        for finding in findings { print("\(finding.rule): \(finding.message)") }
        exit(findings.isEmpty ? 0 : 1)
    case ("breaking", 3), ("breaking", 4):
        let all = arguments.count == 4 && arguments[3] == "--all"
        let changes = SchemaComparator().compare(old: load(arguments[1]), new: load(arguments[2]))
        let shown = all ? changes : changes.filter(\.breaksTheWire)
        for change in shown { print("\(change.bufRule): \(change.description)") }
        exit(changes.contains(where: \.breaksTheWire) ? 1 : 0)
    default:
        FileHandle.standardError.write(
            Data("usage: aemi-proto-check lint SET.pb | aemi-proto-check breaking OLD.pb NEW.pb [--all]\n".utf8))
        exit(2)
}
