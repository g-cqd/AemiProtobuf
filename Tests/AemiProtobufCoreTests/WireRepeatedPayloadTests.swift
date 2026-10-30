import AemiProtobufCore
import Testing

/// Roadmap 0019: the one-pass writers of repeated strings and bytes write exactly what one record per element writes.
@Suite struct WireRepeatedPayloadTests {
    private static let strings: [[String]] = [
        [], [""], ["a", "", "é漢🎉"], [String(repeating: "x", count: 200), "y"], (0 ..< 50).map { "item \($0)" }
    ]

    @Test(arguments: strings, [FieldNumber(1), 16, 2_048])
    func `repeated strings are written as one record per element`(values: [String], field: FieldNumber) {
        var bulk = WireWriter()
        bulk.appendRepeatedStrings(field: field, values)
        var single = WireWriter()
        for value in values {
            single.appendTag(field, .lengthDelimited)
            single.appendString(value)
        }
        #expect(bulk.bytes == single.bytes)
    }

    @Test(arguments: strings, [FieldNumber(1), 16])
    func `repeated bytes are written as one record per element, after what is already written`(
        values: [String], field: FieldNumber
    ) {
        let payloads = values.map { Array($0.utf8) }
        var bulk = WireWriter()
        bulk.appendVarint(300)
        bulk.appendRepeatedBytes(field: field, payloads)
        var single = WireWriter()
        single.appendVarint(300)
        for payload in payloads {
            single.appendTag(field, .lengthDelimited)
            single.appendBytes(payload)
        }
        #expect(bulk.bytes == single.bytes)
    }
}
