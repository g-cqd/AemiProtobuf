import AemiProtobufCore
import AemiProtobufSchema
import Benchmark
import Foundation

/// Baselines for the supported schema subset; failures invalidate a run rather than timing an empty fallback.
struct SchemaBenchmarks {
    static func register() {
        let source = """
            syntax = "proto3";
            package benchmark;
            message Record {
              int64 id = 1;
              string name = 2;
              repeated int32 values = 3;
            }
            """
        Benchmark("Schema.parse3Fields") { benchmark in
            for _ in benchmark.scaledIterations {
                let descriptor = try ProtoParser().parse(source)
                guard descriptor.messages.first?.fields.count == 3 else {
                    benchmark.error("Parser returned an incomplete descriptor")
                    return
                }
                blackHole(descriptor)
            }
        }
        // Roadmap 0002: descriptor.proto (1,300 lines: options, extensions, defaults, reservations), compiled as protoc does.
        let descriptorProto = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appending(
                path: "../../Tests/AemiProtobufSchemaTests/Resources/parser/src/google/protobuf/descriptor.proto")
        let descriptorSource = (try? String(contentsOf: descriptorProto, encoding: .utf8)) ?? ""
        let compiler = ProtoCompiler { $0 == "google/protobuf/descriptor.proto" ? descriptorSource : nil }
        Benchmark("Schema.compileDescriptorProto") { benchmark in
            for _ in benchmark.scaledIterations {
                let set = try compiler.compile(["google/protobuf/descriptor.proto"])
                guard set.files.first?.messages.count == 23 else {
                    benchmark.error("descriptor.proto compiled to \(set.files.first?.messages.count ?? 0) messages")
                    return
                }
                blackHole(set)
            }
        }
        let descriptor = MessageDescriptor(
            name: "Record",
            fields: [
                FieldDescriptor(name: "id", number: 1, type: .int64),
                FieldDescriptor(name: "name", number: 2, type: .string),
                FieldDescriptor(name: "values", number: 3, label: .repeated, type: .int32)
            ])
        let bytes: [UInt8] = [0x08, 0x2A, 0x12, 0x03, 0x41, 0x64, 0x61, 0x1A, 0x03, 0x01, 0x02, 0x03]
        Benchmark("Schema.validate3Fields") { benchmark in
            let validator = WireValidator()
            for _ in benchmark.scaledIterations {
                let errors = validator.validate(bytes: bytes, against: descriptor)
                guard errors.isEmpty else {
                    benchmark.error("Validator rejected valid benchmark bytes: \(errors)")
                    return
                }
                blackHole(errors)
            }
        }

        // Roadmap 0007: nested validation, a message holding 100 messages of a three-field message, through the work queue.
        let nested = FileDescriptorSet(files: [
            FileDescriptor(
                name: "nested.proto", package: "bench",
                messages: [
                    MessageDescriptor(
                        name: "Outer",
                        fields: [
                            FieldDescriptor(
                                name: "items", number: 1, label: .repeated, type: .message, typeName: ".bench.Inner")
                        ]),
                    MessageDescriptor(
                        name: "Inner",
                        fields: [
                            FieldDescriptor(name: "id", number: 1, type: .int64),
                            FieldDescriptor(name: "name", number: 2, type: .string),
                            FieldDescriptor(name: "values", number: 3, label: .repeated, type: .int32)
                        ])
                ])
        ])
        var outer = WireWriter()
        for index in 0 ..< 100 {
            try? outer.appendMessage(field: 1) { w throws(WireError) in
                w.appendTag(1, .varint)
                w.appendVarint(UInt64(index))
                w.appendTag(2, .lengthDelimited)
                w.appendString("item \(index)")
                w.appendPackedVarints(field: 3, [Int32(index), 1, 2])
            }
        }
        let nestedBytes = outer.bytes
        Benchmark("Schema.validateNested100") { benchmark in
            let validator = WireValidator()
            for _ in benchmark.scaledIterations {
                let findings = validator.validate(bytes: nestedBytes, against: "bench.Outer", in: nested)
                guard findings.isEmpty else {
                    benchmark.error("Validator rejected valid nested bytes: \(findings)")
                    return
                }
                blackHole(findings)
            }
        }
    }
}
