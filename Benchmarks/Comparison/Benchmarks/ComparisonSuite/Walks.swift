import AemiJSON
import AemiProtobufCore

/// Reads every value of a JSON document through the lazy accessors, iteratively. The untyped hot path of AemiJSON.
func jsonWalk(_ json: JSON) -> Int {
    var sum = 0
    var stack = [json]
    while let node = stack.popLast() {
        if let object = node.object {
            for (_, value) in object { stack.append(value) }
        } else if let array = node.array {
            stack.append(contentsOf: array)
        } else if let i = node.int {
            sum &+= i
        } else if let d = node.double {
            sum &+= Int(d)
        } else if let s = node.string {
            sum &+= s.utf8.count
        } else if let b = node.bool {
            sum &+= b ? 1 : 0
        }
    }
    return sum
}

/// Reads every field of a `Users` message, validating strings and nesting, as a decoder must; the protobuf counterpart of
/// ``jsonWalk(_:)``. Fields not in the schema are skipped.
func protobufWalk(_ bytes: [UInt8]) throws(WireError) -> Int {
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
                        case (1, .varint), (5, .varint), (6, .varint), (7, .varint):
                            sum &+= Int(truncatingIfNeeded: try r.readVarint())
                        case (2, .lengthDelimited), (3, .lengthDelimited), (4, .lengthDelimited), (9, .lengthDelimited):
                            sum &+= try r.readString().utf8.count
                        case (8, .fixed64): sum &+= Int(truncatingIfNeeded: try r.readFixed64())
                        case (10, .lengthDelimited):
                            try r.readMessage { r throws(WireError) in
                                while let inner = try r.nextTag() {
                                    switch inner.wireType {
                                        case .lengthDelimited: sum &+= try r.readString().utf8.count
                                        case .varint: sum &+= Int(truncatingIfNeeded: try r.readVarint())
                                        default: try r.skipField(inner)
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

/// Reads `id` and `login` of every user and skips the rest: the protobuf counterpart of reading two fields of each element
/// from a JSON tape.
func protobufReadTwoFields(_ bytes: [UInt8]) throws(WireError) -> Int {
    try WireReader.withReader(over: bytes) { r throws(WireError) in
        var acc = 0
        while let outer = try r.nextTag() {
            guard outer.fieldNumber == 1 else {
                try r.skipField(outer)
                continue
            }
            try r.readMessage { r throws(WireError) in
                while let tag = try r.nextTag() {
                    switch (tag.fieldNumber.rawValue, tag.wireType) {
                        case (1, .varint): acc &+= Int(truncatingIfNeeded: try r.readVarint())
                        case (2, .lengthDelimited): acc &+= try r.readString().utf8.count
                        default: try r.skipField(tag)
                    }
                }
            }
        }
        return acc
    }
}

/// Counts the top-level records without reading their contents: the cheapest structural pass the wire format allows.
func protobufCountRecords(_ bytes: [UInt8]) throws(WireError) -> Int {
    try WireReader.withReader(over: bytes) { r throws(WireError) in
        var count = 0
        while let tag = try r.nextTag() {
            try r.skipField(tag)
            count += 1
        }
        return count
    }
}

/// Descends a chain of nested messages to the innermost varint without recursion, one reader per level.
func protobufDescend(_ bytes: [UInt8]) throws(WireError) -> Int {
    var range = 0 ..< bytes.count
    var depth = 0
    while true {
        let next: Range<Int>? = try WireReader.withReader(over: bytes, in: range, depth: depth) { r throws(WireError) in
            guard let tag = try r.nextTag() else { return nil }
            if tag.wireType == .lengthDelimited { return try r.readPayloadRange() }
            _ = try r.readVarint()
            return nil
        }
        guard let inner = next else { return depth }
        range = inner
        depth += 1
    }
}
