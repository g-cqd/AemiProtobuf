import AemiProtobuf
import Foundation

// The protobuf conformance testee: the runner writes length-prefixed ConformanceRequests to standard input and reads
// length-prefixed ConformanceResponses from standard output (conformance/conformance.proto). Binary in, binary out; JSON,
// JSPB and text format are answered "skipped" until roadmap 0010.

/// A message type the runner names, as the generated type that reads and writes it.
struct Testee: Sendable {
    let decode: @Sendable ([UInt8]) throws -> any Sendable
    let encode: @Sendable (any Sendable) throws -> [UInt8]

    static func of<T: AemiProtoFastEncodable & AemiProtoFastDecodable & Codable & Sendable>(_: T.Type) -> Testee {
        Testee(
            decode: { try ProtobufDecoder().decode(T.self, fromBytes: $0) },
            encode: { value in
                guard let value = value as? T else { throw ProtobufEncodingError.unsupported("\(T.self)") }
                return try ProtobufEncoder().encodeToBytes(value)
            })
    }
}

enum Registry {
    static let testees: [String: Testee] = [
        "protobuf_test_messages.proto3.TestAllTypesProto3": .of(ProtobufTestMessages_Proto3_TestAllTypesProto3.self),
        "protobuf_test_messages.proto2.TestAllTypesProto2": .of(ProtobufTestMessages_Proto2_TestAllTypesProto2.self),
        "protobuf_test_messages.editions.TestAllTypesEdition2023":
            .of(ProtobufTestMessages_Editions_TestAllTypesEdition2023.self),
        "protobuf_test_messages.editions.proto2.TestAllTypesProto2":
            .of(ProtobufTestMessages_Editions_Proto2_TestAllTypesProto2.self),
        "protobuf_test_messages.editions.proto3.TestAllTypesProto3":
            .of(ProtobufTestMessages_Editions_Proto3_TestAllTypesProto3.self),
        "conformance.FailureSet": .of(Conformance_FailureSet.self)
    ]
}

func respond(to request: Conformance_ConformanceRequest) -> Conformance_ConformanceResponse.OneOf_Result {
    guard let testee = Registry.testees[request.messageType] else {
        return .skipped("no generated type for \(request.messageType)")
    }
    guard case .protobufPayload(let payload)? = request.payload else {
        return .skipped("only binary input is supported")
    }
    let message: any Sendable
    do {
        message = try testee.decode(payload)
    } catch {
        return .parseError("\(error)")
    }
    guard request.requestedOutputFormat == .protobuf else { return .skipped("only binary output is supported") }
    do {
        return .protobufPayload(try testee.encode(message))
    } catch {
        return .serializeError("\(error)")
    }
}

func read(_ count: Int) -> [UInt8]? {
    var bytes: [UInt8] = []
    while bytes.count < count {
        let chunk = FileHandle.standardInput.readData(ofLength: count - bytes.count)
        if chunk.isEmpty { return nil }
        bytes += chunk
    }
    return bytes
}

while let header = read(4) {
    let length = Int(header[0]) | Int(header[1]) << 8 | Int(header[2]) << 16 | Int(header[3]) << 24
    guard let body = read(length) else { break }
    let result: Conformance_ConformanceResponse.OneOf_Result
    do {
        result = respond(to: try ProtobufDecoder().decode(Conformance_ConformanceRequest.self, fromBytes: body))
    } catch {
        result = .runtimeError("cannot read the request: \(error)")
    }
    let response = (try? ProtobufEncoder().encodeToBytes(Conformance_ConformanceResponse(result: result))) ?? []
    let size = UInt32(response.count)
    FileHandle.standardOutput.write(
        Data([UInt8(size & 0xFF), UInt8(size >> 8 & 0xFF), UInt8(size >> 16 & 0xFF), UInt8(size >> 24)] + response))
}
