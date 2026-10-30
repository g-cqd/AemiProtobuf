import AemiProtobuf
import AemiProtobufCore
import AemiProtobufSchema
import Benchmark
import Foundation

/// Roadmap 0006's probe: the 1,000-user corpus read for half its fields (id, name, active, the address's city, stamp) through a
/// ``ProtoMessageView`` and through a full macro decode; and the same corpus through ``DynamicSchema``.
enum ViewBenchmarks {
    /// The corpus's schema, as the descriptors `protoc` would write for it.
    static let users: FileDescriptorSet = {
        func field(_ name: String, _ number: Int32, _ type: FieldType, repeated: Bool = false, typeName: String = "")
            -> FieldDescriptor
        {
            FieldDescriptor(
                name: name, number: number, label: repeated ? .repeated : .optional, type: type, typeName: typeName)
        }
        let address = MessageDescriptor(
            name: "Address", fields: [field("street", 1, .string), field("city", 2, .string), field("zip", 3, .int32)])
        let user = MessageDescriptor(
            name: "User",
            fields: [
                field("id", 1, .int64), field("name", 2, .string), field("email", 3, .string),
                field("active", 4, .bool),
                field("score", 5, .double), field("tags", 6, .string, repeated: true),
                field("samples", 7, .int32, repeated: true), field("address", 8, .message, typeName: ".bench.Address"),
                field("delta", 9, .int32), field("stamp", 10, .uint64)
            ])
        let users = MessageDescriptor(
            name: "Users", fields: [field("users", 1, .message, repeated: true, typeName: ".bench.User")])
        return FileDescriptorSet(files: [
            FileDescriptor(name: "bench.proto", package: "bench", messages: [users, user, address])
        ])
    }()

    /// Half the fields of every user, through the view: no `String`, no array.
    static func readHalf(view bytes: [UInt8]) throws(WireError) -> Int {
        var sum = 0
        for user in try ProtoMessageView(bytes).messages(1) {
            sum &+= Int(truncatingIfNeeded: user.int64(1) ?? 0)
            sum &+= user.withBytes(2) { $0.count } ?? 0
            sum &+= user.bool(4) == true ? 1 : 0
            sum &+= try user.message(8)?.withBytes(2) { $0.count } ?? 0
            sum &+= Int(truncatingIfNeeded: user.uint64(10) ?? 0)
        }
        return sum
    }

    /// The same fields, after a full decode.
    static func readHalf(decoded users: MacroUsers) -> Int {
        var sum = 0
        for user in users.users {
            sum &+= Int(truncatingIfNeeded: user.id)
            sum &+= user.name.utf8.count
            sum &+= user.active ? 1 : 0
            sum &+= user.address.city.utf8.count
            sum &+= Int(truncatingIfNeeded: user.stamp)
        }
        return sum
    }

    static func register() {
        let users = MacroUsers(UserRecord.corpus(count: 1_000))
        let schema = DynamicSchema(Self.users)
        let bytes: [UInt8]
        let dynamic: DynamicMessage
        do {
            bytes = try ProtobufEncoder().encodeToBytes(users)
            guard try readHalf(view: bytes) == readHalf(decoded: users) else {
                throw CheckFailure("the view reads other values than the decoder")
            }
            dynamic = try schema.decode(bytes, as: "bench.Users")
            guard try schema.encode(dynamic) == bytes else {
                throw CheckFailure("the dynamic message does not round-trip")
            }
        } catch {
            FileHandle.standardError.write(Data("view benchmarks: \(error)\n".utf8))
            exit(1)
        }
        let decoder = ProtobufDecoder()
        Benchmark("View.readHalf") { bm in
            for _ in bm.scaledIterations { blackHole(try readHalf(view: bytes)) }
        }
        Benchmark("Coder.macro.decodeReadHalf") { bm in
            for _ in bm.scaledIterations {
                blackHole(readHalf(decoded: try decoder.decode(MacroUsers.self, fromBytes: bytes)))
            }
        }
        Benchmark("Dynamic.decode") { bm in
            for _ in bm.scaledIterations { blackHole(try schema.decode(bytes, as: "bench.Users")) }
        }
        Benchmark("Dynamic.encode") { bm in
            for _ in bm.scaledIterations { blackHole(try schema.encode(dynamic)) }
        }
    }
}
