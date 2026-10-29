import AemiProtobufCore
import AemiProtobufSchema

/// protoc's plugin protocol (`google/protobuf/compiler/plugin.proto`): a `CodeGeneratorRequest` in, a `CodeGeneratorResponse` out.
/// The plugin says it supports proto3 `optional` and editions (proto2 through 2023).
public enum ProtocPlugin {
    /// `FEATURE_PROTO3_OPTIONAL | FEATURE_SUPPORTS_EDITIONS`.
    static let supportedFeatures: UInt64 = 0b11
    static let minimumEdition: Int32 = 998
    static let maximumEdition: Int32 = 1000

    /// The response to `request`: the generated files, or the error protoc should show.
    public static func run(request: [UInt8]) -> [UInt8] {
        var writer = WireWriter()
        do {
            let (files, parameter, set) = try decode(request)
            let options = try GeneratorOptions(parameter: parameter)
            let generated = try SwiftGenerator.generate(set, files: files, options: options)
            writeFeatures(&writer)
            for file in generated {
                try writer.appendMessage(field: 15) { w throws(WireError) in
                    w.appendTag(1, .lengthDelimited)
                    w.appendString(file.name)
                    w.appendTag(15, .lengthDelimited)
                    w.appendString(file.content)
                }
            }
        } catch {
            writer = WireWriter()
            writer.appendTag(1, .lengthDelimited)
            writer.appendString("protoc-gen-aemi: \(error)")
            writeFeatures(&writer)
        }
        return writer.bytes
    }

    private static func writeFeatures(_ writer: inout WireWriter) {
        writer.appendTag(2, .varint)
        writer.appendVarint(supportedFeatures)
        writer.appendTag(3, .varint)
        writer.appendInt32(minimumEdition)
        writer.appendTag(4, .varint)
        writer.appendInt32(maximumEdition)
    }

    /// `file_to_generate` (1), `parameter` (2), `proto_file` (15); the compiler version is skipped.
    private static func decode(_ bytes: [UInt8]) throws -> ([String], String, FileDescriptorSet) {
        try WireReader.withReader(over: bytes) { r throws(WireError) -> ([String], String, FileDescriptorSet) in
            var files: [String] = []
            var parameter = ""
            var set = FileDescriptorSet()
            while let tag = try r.nextTag() {
                switch (tag.fieldNumber.rawValue, tag.wireType) {
                    case (1, .lengthDelimited): files.append(try r.readString())
                    case (2, .lengthDelimited): parameter = try r.readString()
                    case (15, .lengthDelimited):
                        set.files.append(
                            try r.readMessage { r throws(WireError) in try FileDescriptor.decode(from: &r) })
                    default: try r.skipField(tag)
                }
            }
            return (files, parameter, set)
        }
    }
}
