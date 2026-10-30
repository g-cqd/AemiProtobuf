import Foundation
import PackagePlugin

/// `swift package protobuf-check lint SET.pb` and `swift package protobuf-check breaking OLD.pb NEW.pb [--all]`: the
/// schema linter and the breaking-change check, from a package (roadmap 0008). Paths are relative to the package.
@main
struct ProtobufCheck: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let tool = try context.tool(named: "aemi-proto-check")
        let root = context.package.directoryURL
        let resolved = arguments.map { argument in
            argument.hasSuffix(".pb") && !argument.hasPrefix("/") ? root.appending(path: argument).path : argument
        }
        let process = Process()
        process.executableURL = tool.url
        process.arguments = resolved
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            Diagnostics.error("protobuf-check found problems (exit \(process.terminationStatus))")
            return
        }
    }
}
