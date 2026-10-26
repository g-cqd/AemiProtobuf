import AemiProtobufSchema
import Benchmark

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
    }
}
