// libFuzzer entry point (roadmap 0013). Built only when `AEMIPROTOBUF_FUZZ` is set (see `Package.swift`), with
// `-sanitize=fuzzer -parse-as-library`, which the Linux toolchain supports and the Darwin SDK does not:
//   AEMIPROTOBUF_FUZZ=1 swift build -c release --product AemiProtobufFuzz
//   .build/release/AemiProtobufFuzz -max_total_time=600 Tests/AemiProtobufTests/Resources
//
// The contract: for any byte string every entry either succeeds or throws, never traps, never reads out of bounds, never loops
// unbounded; and a message that decodes re-encodes to bytes that decode to the same value. A crash is a finding.

import AemiProtobuf
import AemiProtobufCore
import AemiProtobufSchema

func roundTrip<T: AemiProtoFastEncodable & AemiProtoFastDecodable & Codable & Equatable>(
    _ type: T.Type, _ bytes: [UInt8]
) {
    guard let value = try? ProtobufDecoder().decode(T.self, fromBytes: bytes) else { return }
    guard let encoded = try? ProtobufEncoder().encodeToBytes(value) else {
        fatalError("\(T.self) decoded but did not encode")
    }
    guard let again = try? ProtobufDecoder().decode(T.self, fromBytes: encoded), again == value else {
        fatalError("\(T.self) did not survive a round trip")
    }
}

@_cdecl("LLVMFuzzerTestOneInput")
public func LLVMFuzzerTestOneInput(_ start: UnsafePointer<UInt8>?, _ count: Int) -> CInt {
    guard let start, count > 0 else { return 0 }
    let bytes = [UInt8](UnsafeBufferPointer(start: start, count: count))

    // The wire core: every field skipped, then every field kept as unknown.
    _ = try? WireReader.withReader(over: bytes) { r throws(WireError) in
        var unknown = UnknownFields()
        while let tag = try r.nextTag() { try r.readUnknownField(tag, into: &unknown) }
    }
    roundTrip(FuzzMessage.self, bytes)
    roundTrip(FuzzRequired.self, bytes)
    _ = try? ProtobufDecoder().decode(FuzzCodable.self, from: bytes)

    // Descriptors, and the validator against the descriptors they describe.
    if let set = try? FileDescriptorSet.decode(from: bytes) {
        guard let encoded = try? set.encode(), (try? FileDescriptorSet.decode(from: encoded)) == set else {
            fatalError("a descriptor set did not survive a round trip")
        }
        if let message = set.files.first?.messages.first {
            _ = WireValidator().validate(bytes: bytes, against: message)
        }
    }

    // Framing, fed in two pieces.
    var frames = FrameDecoder(format: .grpc, maxFrameBytes: 1 << 16)
    frames.push(bytes.prefix(count / 2))
    frames.push(bytes.dropFirst(count / 2))
    while (try? frames.next()) as Frame?? != nil {}
    return 0
}
