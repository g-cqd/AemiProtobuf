import ComparisonShared
import Foundation

// Verifies that every codec round-trips the corpus, then prints encoded sizes. Exit 1 if any check fails: a size or a
// speed for a codec that does not round-trip would be meaningless.
var failed = false
// `--write DIR` also writes the 100-record message, for `protoc --decode` (see comparison.proto).
if let flag = CommandLine.arguments.firstIndex(of: "--write"), flag + 1 < CommandLine.arguments.count {
    do {
        let codecs = try Codecs(count: 100)
        try Data(codecs.protoFast).write(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1] + "/users-n100.bin"))
    } catch {
        FileHandle.standardError.write(Data("--write failed: \(error)\n".utf8))
        exit(1)
    }
}
print(
    "| records | AemiJSON bytes | Foundation bytes | AemiProtobuf bytes | protobuf / JSON | bytes per record (JSON) | bytes per record (protobuf) |"
)
print("|---:|---:|---:|---:|---:|---:|---:|")
for n in [1, 10, 100, 2_000, 20_000] {
    do {
        let codecs = try Codecs(count: n)
        let verification = codecs.verify()
        for finding in verification.findings {
            FileHandle.standardError.write(Data("n=\(n): \(finding)\n".utf8))
            failed = true
        }
        let ratio = Double(codecs.protoFast.count) / Double(codecs.jsonAemi.count)
        print(
            "| \(n) | \(codecs.jsonAemi.count) | \(codecs.jsonFoundation.count) | \(codecs.protoFast.count) | \(String(format: "%.3f", ratio)) | \(codecs.jsonAemi.count / n) | \(codecs.protoFast.count / n) |"
        )
    } catch {
        FileHandle.standardError.write(Data("n=\(n): setup threw \(error)\n".utf8))
        failed = true
    }
}
exit(failed ? 1 : 0)
