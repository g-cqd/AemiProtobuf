import AemiProtobufCore
import AemiProtobufSchema
import Testing

struct WireValidatorBoundaryTests {
    @Test func `duplicate descriptor numbers return a finding instead of trapping`() {
        let descriptor = MessageDescriptor(
            name: "Duplicate",
            fields: [
                FieldDescriptor(name: "first", number: 1), FieldDescriptor(name: "second", number: 1)
            ])
        #expect(WireValidator().validate(bytes: [], against: descriptor) == [.invalidDescriptorNumber(1)])
    }

    @Test(arguments: [0, 1, 2])
    func `findings are capped with an explicit incomplete marker`(limit: Int) {
        let sut = WireValidator(allowUnknownFields: false, maxFindings: limit)
        let errors = sut.validate(bytes: [0x08, 0, 0x08, 0, 0x08, 0], against: MessageDescriptor())
        #expect(errors.count == max(1, limit) + 1)
        #expect(errors.last == .findingLimitReached)
    }

    @Test func `required field findings obey the same cap`() {
        let descriptor = MessageDescriptor(fields: [
            FieldDescriptor(name: "first", number: 1, label: .required),
            FieldDescriptor(name: "second", number: 2, label: .required)
        ])
        #expect(
            WireValidator(maxFindings: 1).validate(bytes: [], against: descriptor) == [
                .requiredFieldMissing(field: 1, name: "first"), .findingLimitReached
            ])
    }

    @Test func `a wire mismatch does not satisfy a required field`() {
        let descriptor = MessageDescriptor(fields: [FieldDescriptor(name: "id", number: 1, label: .required)])
        let errors = WireValidator().validate(bytes: [0x0D, 0, 0, 0, 0], against: descriptor)
        #expect(errors.last == .requiredFieldMissing(field: 1, name: "id"))
    }

    @Test func `packed values do not consume message nesting depth`() {
        let descriptor = MessageDescriptor(fields: [FieldDescriptor(name: "values", number: 1, label: .repeated)])
        let sut = WireValidator(limits: WireLimits(maxDepth: 0))
        #expect(sut.validate(bytes: [0x0A, 0x01, 0x01], against: descriptor).isEmpty)
    }

    @Test func `corruption does not report unvisited required fields as missing`() {
        let descriptor = MessageDescriptor(fields: [FieldDescriptor(name: "id", number: 1, label: .required)])
        #expect(WireValidator().validate(bytes: [0x80], against: descriptor) == [.wireCorrupted(.truncated(at: 0))])
    }

    @Test(arguments: [16, 17, 40])
    func `descriptors on both sides of the linear-search limit validate the same way`(count: Int) {
        let fields = (1 ... count).map { FieldDescriptor(name: "f\($0)", number: Int32($0), type: .int32) }
        let descriptor = MessageDescriptor(name: "Wide", fields: fields)
        var w = WireWriter()
        w.appendTag(FieldNumber(rawValue: UInt32(count)) ?? 1, .varint)
        w.appendVarint(7)
        #expect(WireValidator().validate(bytes: w.bytes, against: descriptor).isEmpty)
        // a wrong wire type on the last field is found, so the lookup reached it
        var wrong = WireWriter()
        wrong.appendTag(FieldNumber(rawValue: UInt32(count)) ?? 1, .fixed32)
        wrong.appendFixed32(7)
        #expect(WireValidator().validate(bytes: wrong.bytes, against: descriptor).count == 1)
        // a duplicate number is found whichever search is used
        let duplicated = MessageDescriptor(name: "Dup", fields: fields + [FieldDescriptor(name: "again", number: 1)])
        #expect(WireValidator().validate(bytes: [], against: duplicated) == [.invalidDescriptorNumber(1)])
    }
}
