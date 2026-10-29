import Foundation
import Testing

/// The bytes of a file in `Resources/`, which protoc wrote.
enum TestResource {
    static func bytes(_ name: String, extension ext: String = "bin") throws -> [UInt8] {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources"))
        return [UInt8](try Data(contentsOf: url))
    }
}
