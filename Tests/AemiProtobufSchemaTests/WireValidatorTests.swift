import AemiProtobufCore
import AemiProtobufSchema
import Foundation
import Testing

struct WireValidatorTests {
    let userDescriptor = MessageDescriptor(
        name: "User",
        fields: [
            FieldDescriptor(name: "id", number: 1, label: .optional, type: .int64),
            FieldDescriptor(name: "name", number: 2, label: .optional, type: .string),
            FieldDescriptor(name: "samples", number: 3, label: .repeated, type: .int32),
            FieldDescriptor(name: "token", number: 4, label: .required, type: .string)
        ]
    )

    @Test func `valid wire bytes pass validation with 0 errors`() throws {
        var w = WireWriter()
        w.appendTag(1, .varint)
        w.appendVarint(42)
        w.appendTag(2, .lengthDelimited)
        w.appendString("Alice")
        w.appendTag(4, .lengthDelimited)
        w.appendString("secret-token")

        let validator = WireValidator()
        let errors = validator.validate(bytes: w.bytes, against: userDescriptor)
        #expect(errors.isEmpty)
    }

    @Test func `missing required field is reported`() {
        var w = WireWriter()
        w.appendTag(1, .varint)
        w.appendVarint(42)

        let validator = WireValidator()
        let errors = validator.validate(bytes: w.bytes, against: userDescriptor)
        #expect(errors == [.requiredFieldMissing(field: 4, name: "token")])
    }

    @Test func `unexpected wire type is reported`() {
        var w = WireWriter()
        // Field 1 is expected to be varint, but written as fixed32
        w.appendTag(1, .fixed32)
        w.appendFixed32(42)
        w.appendTag(4, .lengthDelimited)
        w.appendString("token")

        let validator = WireValidator()
        let errors = validator.validate(bytes: w.bytes, against: userDescriptor)
        #expect(
            errors.contains { err in
                if case .unexpectedWireType(field: 1, expected: .varint, actual: .fixed32, at: _) = err { return true }
                return false
            })
    }

    @Test func `unknown field disallowed is reported`() {
        var w = WireWriter()
        w.appendTag(4, .lengthDelimited)
        w.appendString("token")
        w.appendTag(99, .varint)
        w.appendVarint(1)

        let validator = WireValidator(allowUnknownFields: false)
        let errors = validator.validate(bytes: w.bytes, against: userDescriptor)
        #expect(
            errors.contains { err in
                if case .unknownField(let num, at: _) = err, num.rawValue == 99 { return true }
                return false
            })
    }
}
