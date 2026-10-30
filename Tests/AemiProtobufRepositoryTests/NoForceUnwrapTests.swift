import Foundation
import Testing

/// Roadmap 0013: the library forces nothing. Broken on purpose first: every force in the fixture is found, and nothing in the
/// clean one.
struct NoForceUnwrapTests {
    @Test func `every kind of force is found`() {
        let forced = """
            let a = b!
            let c = d as! Int
            let e = try! f()
            var g: Int!
            let h = i[0]!.j
            let k = l?.m!
            """
        #expect(ForceUnwrapScan.findings([("a.swift", forced)]).count == 6)
    }

    @Test func `inequality, negation, and a bang in a string or a comment are not forces`() {
        let clean = """
            if a != b, !c { print("wow!") } // really!
            /* x! */ let d = !e
            """
        #expect(ForceUnwrapScan.findings([("b.swift", clean)]).isEmpty)
    }

    @Test func `the library forces nothing`() {
        var files: [(String, String)] = []
        var pending = [DocumentationLayout.repositoryRoot.appending(path: "Sources")]
        while let directory = pending.popLast() {
            let entries =
                (try? FileManager.default.contentsOfDirectory(
                    at: directory, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            for entry in entries {
                if (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    pending.append(entry)
                } else if entry.pathExtension == "swift", let text = try? String(contentsOf: entry, encoding: .utf8) {
                    files.append((entry.lastPathComponent, text))
                }
            }
        }
        #expect(files.count > 50, "the scan must see the library: \(files.count) files")
        let found = ForceUnwrapScan.findings(files)
        #expect(found.isEmpty, "\(found.joined(separator: "\n"))")
    }
}
