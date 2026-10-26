import AemiProtobufCore
import AemiProtobufSchema
import Testing

struct WireValidatorMalformedTests {
    @Test(arguments: [Int32.min, -1, 0, 536_870_912, Int32.max])
    func `invalid descriptor numbers are rejected before reading input`(number: Int32) {
        let descriptor = MessageDescriptor(name: "Invalid", fields: [FieldDescriptor(name: "value", number: number)])
        #expect(WireValidator().validate(bytes: [], against: descriptor) == [.invalidDescriptorNumber(number)])
    }

    @Test func `packed corruption offsets refer to the original input`() {
        let descriptor = MessageDescriptor(
            name: "Packed", fields: [FieldDescriptor(name: "values", number: 1, label: .repeated, type: .int32)])
        #expect(
            WireValidator().validate(bytes: [0x0A, 0x01, 0x80], against: descriptor) == [
                .wireCorrupted(.truncated(at: 2))
            ])
    }

    @Test(arguments: [[UInt8](arrayLiteral: 0x0A, 0x80), [0x0A, 0x02, 0x61]])
    func `truncated string framing is corruption rather than invalid UTF8`(bytes: [UInt8]) {
        let descriptor = MessageDescriptor(
            name: "Text", fields: [FieldDescriptor(name: "text", number: 1, type: .string)])
        let errors = WireValidator().validate(bytes: bytes, against: descriptor)
        #expect(errors.count == 1)
        #expect(
            errors.contains {
                if case .wireCorrupted = $0 { return true }
                return false
            })
    }

    @Test func `invalid UTF8 does not hide subsequent fields`() {
        let descriptor = MessageDescriptor(
            name: "Text", fields: [FieldDescriptor(name: "text", number: 1, type: .string)])
        let errors = WireValidator(allowUnknownFields: false)
            .validate(
                bytes: [0x0A, 0x01, 0xFF, 0x10, 0x01], against: descriptor)
        #expect(errors.count == 2)
        #expect(errors.first == .invalidUTF8(field: 1, at: 2))
    }

    @Test(arguments: [FieldType.int32, .fixed32, .fixed64])
    func `malformed packed scalar payloads are corruption`(type: FieldType) {
        let descriptor = MessageDescriptor(
            name: "Packed", fields: [FieldDescriptor(name: "values", number: 1, label: .repeated, type: type)])
        let errors = WireValidator().validate(bytes: [0x0A, 0x01, 0x80], against: descriptor)
        #expect(errors.count == 1)
        #expect(
            errors.contains {
                if case .wireCorrupted = $0 { return true }
                return false
            })
    }

    @Test(arguments: [FieldType.int32, .fixed32, .fixed64])
    func `empty packed scalar payloads are valid`(type: FieldType) {
        let descriptor = MessageDescriptor(
            name: "Packed", fields: [FieldDescriptor(name: "values", number: 1, label: .repeated, type: type)])
        #expect(WireValidator().validate(bytes: [0x0A, 0x00], against: descriptor).isEmpty)
    }
}
