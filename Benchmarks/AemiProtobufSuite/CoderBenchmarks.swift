import AemiProtobuf
import AemiProtobufCore
import AemiProtobufSchema
import Benchmark
import Foundation

/// The coders, the packed paths and the schema tools, on the allocation gate. Setup that fails stops the run with the reason.
func registerCoderBenchmarks() {
    let records = UserRecord.corpus(count: 1_000)
    let macroUsers = MacroUsers(records)
    let genericUsers = GenericUsers(macroUsers)
    let encoder = ProtobufEncoder()
    let decoder = ProtobufDecoder()
    let fast: [UInt8]
    do {
        fast = try encoder.encodeToBytes(macroUsers)
        let generic = try encoder.encodeToBytes(genericUsers)
        guard fast == generic else {
            throw CheckFailure("the generic path writes different bytes (\(generic.count) against \(fast.count))")
        }
        guard try decoder.decode(MacroUsers.self, fromBytes: fast) == macroUsers else {
            throw CheckFailure("the macro path does not round-trip")
        }
        guard try decoder.decode(GenericUsers.self, fromBytes: fast) == genericUsers else {
            throw CheckFailure("the generic path does not round-trip")
        }
    } catch {
        FileHandle.standardError.write(Data("coder benchmarks: \(error)\n".utf8))
        exit(1)
    }

    Benchmark("Coder.macro.encode") { bm in
        for _ in bm.scaledIterations { blackHole(try encoder.encodeToBytes(macroUsers)) }
    }
    Benchmark("Coder.macro.decode") { bm in
        for _ in bm.scaledIterations { blackHole(try decoder.decode(MacroUsers.self, fromBytes: fast)) }
    }
    Benchmark("Coder.generic.encode") { bm in
        for _ in bm.scaledIterations { blackHole(try encoder.encodeToBytes(genericUsers)) }
    }
    Benchmark("Coder.generic.decode") { bm in
        for _ in bm.scaledIterations { blackHole(try decoder.decode(GenericUsers.self, fromBytes: fast)) }
    }

    let doubles = (0 ..< 10_000).map { Double($0) / 7 }
    let longs = (0 ..< 10_000).map { Int64($0) &* 40_503 }
    var packed = WireWriter()
    packed.appendPackedLittleEndian(field: 1, doubles)
    packed.appendPackedVarints(field: 2, longs)
    let packedBytes = packed.bytes
    Benchmark("Packed.write") { bm in
        for _ in bm.scaledIterations {
            var w = WireWriter()
            w.appendPackedLittleEndian(field: 1, doubles)
            w.appendPackedVarints(field: 2, longs)
            blackHole(w.bytes.count)
        }
    }
    Benchmark("Packed.read") { bm in
        for _ in bm.scaledIterations {
            let result = try WireReader.withReader(over: packedBytes) { r throws(WireError) in
                _ = try r.nextTag()
                let a = try r.readPackedLittleEndian(Double.self)
                _ = try r.nextTag()
                return (a.count, try r.readPackedVarints(Int64.self).count)
            }
            blackHole(result)
        }
    }

    // Schema tools: a descriptor set of 50 messages of 10 fields.
    let messages = (0 ..< 50)
        .map { m in
            MessageDescriptor(
                name: "M\(m)",
                fields: (1 ... 10).map { FieldDescriptor(name: "f\($0)", number: Int32($0), type: .int64) })
        }
    let set = FileDescriptorSet(files: [FileDescriptor(name: "bench.proto", package: "bench", messages: messages)])
    guard let setBytes = try? set.encode(), (try? FileDescriptorSet.decode(from: setBytes)) == set else {
        FileHandle.standardError.write(Data("coder benchmarks: the descriptor set does not round-trip\n".utf8))
        exit(1)
    }
    Benchmark("Schema.descriptorSet.encode") { bm in
        for _ in bm.scaledIterations { blackHole(try set.encode()) }
    }
    Benchmark("Schema.descriptorSet.decode") { bm in
        for _ in bm.scaledIterations { blackHole(try FileDescriptorSet.decode(from: setBytes)) }
    }
    Benchmark("Schema.compare.50Messages") { bm in
        let comparator = SchemaComparator()
        for _ in bm.scaledIterations { blackHole(comparator.compare(old: set, new: set)) }
    }
}
