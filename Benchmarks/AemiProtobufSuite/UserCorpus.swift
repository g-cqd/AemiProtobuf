import AemiProtobufCore

/// One message of the corpus the throughput probe used (`docs/research/probes/throughput/user.proto`): ten fields covering varints,
/// strings, a packed repeated `int32`, a nested message, `sint32` and `fixed64`.
struct UserRecord {
    var id: Int64
    var name: String
    var email: String
    var active: Bool
    var score: Double
    var tags: [String]
    var samples: [Int32]
    var street: String
    var city: String
    var zip: Int32
    var delta: Int32
    var stamp: UInt64

    static func corpus(count: Int) -> [UserRecord] {
        (0 ..< count)
            .map { i in
                UserRecord(
                    id: Int64(i) * 7919 + 1, name: "user-\(i)-name", email: "user\(i)@example.com", active: i % 2 == 0,
                    score: Double(i) * 0.25 + 0.5, tags: ["alpha", "beta\(i % 10)", "gamma"],
                    samples: (0 ..< 8).map { Int32($0 * 37 - 5 + i) }, street: "\(i) Main Street", city: "Springfield",
                    zip: Int32(10_000 + i % 9_000), delta: Int32(i % 50) - 25, stamp: UInt64(1_700_000_000 + i))
            }
    }

    /// The `Users { repeated User users = 1; }` message for `records`, written with the core's writer.
    static func encode(_ records: [UserRecord]) throws(WireError) -> [UInt8] {
        var writer = WireWriter(reservingCapacity: records.count * 140)
        for record in records { try writer.appendMessage(field: 1) { w throws(WireError) in try record.write(to: &w) } }
        return writer.bytes
    }

    func write(to w: inout WireWriter) throws(WireError) {
        w.appendTag(1, .varint)
        w.appendVarint(UInt64(bitPattern: id))
        w.appendTag(2, .lengthDelimited)
        w.appendString(name)
        w.appendTag(3, .lengthDelimited)
        w.appendString(email)
        w.appendTag(4, .varint)
        w.appendVarint(active ? 1 : 0)
        w.appendTag(5, .fixed64)
        w.appendDouble(score)
        for tag in tags {
            w.appendTag(6, .lengthDelimited)
            w.appendString(tag)
        }
        try w.appendMessage(field: 7) { w in for sample in samples { w.appendInt32(sample) } }
        try w.appendMessage(field: 8) { w in
            w.appendTag(1, .lengthDelimited)
            w.appendString(street)
            w.appendTag(2, .lengthDelimited)
            w.appendString(city)
            w.appendTag(3, .varint)
            w.appendInt32(zip)
        }
        w.appendTag(9, .varint)
        w.appendVarint(UInt64(ZigZag.encode(delta)))
        w.appendTag(10, .fixed64)
        w.appendFixed64(stamp)
    }

    /// Reads every field of a `Users` message and returns a checksum, so the work cannot be optimised away. Strings are
    /// validated and made, as a decoder must.
    static func checksum(of bytes: [UInt8]) throws(WireError) -> Int {
        try WireReader.withReader(over: bytes) { r throws(WireError) in
            var sum = 0
            while let outer = try r.nextTag() {
                guard outer.fieldNumber == 1 else {
                    try r.skipField(outer)
                    continue
                }
                try r.readMessage { r throws(WireError) in
                    while let tag = try r.nextTag() {
                        switch (tag.fieldNumber.rawValue, tag.wireType) {
                            case (1, .varint), (4, .varint), (9, .varint):
                                sum &+= Int(truncatingIfNeeded: try r.readVarint())
                            case (2, .lengthDelimited), (3, .lengthDelimited), (6, .lengthDelimited):
                                sum &+= try r.readString().utf8.count
                            case (5, .fixed64), (10, .fixed64): sum &+= Int(truncatingIfNeeded: try r.readFixed64())
                            case (7, .lengthDelimited):
                                try r.readMessage { r throws(WireError) in
                                    while !r.isAtEnd { sum &+= Int(try r.readInt32()) }
                                }
                            case (8, .lengthDelimited):
                                try r.readMessage { r throws(WireError) in
                                    while let inner = try r.nextTag() {
                                        if inner.wireType == .lengthDelimited {
                                            sum &+= try r.readString().utf8.count
                                        } else {
                                            sum &+= Int(try r.readInt32())
                                        }
                                    }
                                }
                            default: try r.skipField(tag)
                        }
                    }
                }
            }
            return sum
        }
    }
}
