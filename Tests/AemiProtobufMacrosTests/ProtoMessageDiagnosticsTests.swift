import Foundation
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import AemiProtobufMacros

/// Every shape the macro refuses is diagnosed at the property, and nothing is generated for it.
struct ProtoMessageDiagnosticsTests {
    /// Routes a macro-test failure to Swift Testing, which `assertMacroExpansion` otherwise sends to XCTest.
    private func assertMacroExpansion(
        _ source: String, expandedSource: String, diagnostics: [DiagnosticSpec] = [], macros: [String: any Macro.Type],
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        SwiftSyntaxMacrosGenericTestSupport.assertMacroExpansion(
            source, expandedSource: expandedSource, diagnostics: diagnostics,
            macroSpecs: macros.mapValues { MacroSpec(type: $0) },
            failureHandler: { Issue.record("\($0.message)", sourceLocation: sourceLocation) })
    }

    private let macros: [String: any Macro.Type] = ["ProtoMessage": ProtoMessageMacro.self]

    /// The diagnostic is at the property's name: the column after `var ` on line 3.
    private func expectError(_ source: String, _ message: String, line: Int = 3) {
        let text = source.split(separator: "\n", omittingEmptySubsequences: false)[line - 1]
        let column = (text.range(of: "var ")?.upperBound).map { text.distance(from: text.startIndex, to: $0) + 1 } ?? 5
        assertMacroExpansion(
            source, expandedSource: source.replacingOccurrences(of: "@ProtoMessage\n", with: ""),
            diagnostics: [DiagnosticSpec(message: message, line: line, column: column)], macros: macros)
    }

    @Test func `a property without a field number is refused`() {
        expectError(
            "@ProtoMessage\nstruct M {\n    var a: Int64 = 0\n}", "'a' needs @ProtoField(number)")
    }

    @Test func `a property without a default value is refused`() {
        expectError(
            "@ProtoMessage\nstruct M {\n    @ProtoField(1) var a: Int64\n}",
            "'a' needs a default value: the generated decoder starts from Self()")
    }

    @Test func `a dictionary is refused`() {
        expectError(
            "@ProtoMessage\nstruct M {\n    @ProtoField(1) var a: [String: Int32] = [:]\n}",
            "'a': maps are not supported by @ProtoMessage yet")
    }

    @Test func `a kind that does not fit the Swift type is refused`() {
        expectError(
            "@ProtoMessage\nstruct M {\n    @ProtoField(1, .sint32) var a: String = \"\"\n}",
            "'a' is String, which cannot be a protobuf sint32; use Int32")
    }

    @Test func `a repeated field number is refused`() {
        assertMacroExpansion(
            "@ProtoMessage\nstruct M {\n    @ProtoField(1) var a: Int64 = 0\n    @ProtoField(1) var b: Int64 = 0\n}",
            expandedSource: "struct M {\n    @ProtoField(1) var a: Int64 = 0\n    @ProtoField(1) var b: Int64 = 0\n}",
            diagnostics: [
                DiagnosticSpec(message: "field number 1 is used by 'a' and 'b'", line: 4, column: 24)
            ], macros: macros)
    }

    @Test(arguments: ["0", "536870912", "19500"])
    func `a field number outside the legal range is refused`(number: String) {
        assertMacroExpansion(
            "@ProtoMessage\nstruct M {\n    @ProtoField(\(number)) var a: Int64 = 0\n}",
            expandedSource: "struct M {\n    @ProtoField(\(number)) var a: Int64 = 0\n}",
            diagnostics: [
                DiagnosticSpec(
                    message: "field number \(number) is outside 1...536870911 or in the reserved 19000...19999",
                    line: 3, column: 5)
            ], macros: macros)
    }

    @Test func `a negative or computed field number is not an integer literal`() {
        assertMacroExpansion(
            "@ProtoMessage\nstruct M {\n    @ProtoField(-1) var a: Int64 = 0\n}",
            expandedSource: "struct M {\n    @ProtoField(-1) var a: Int64 = 0\n}",
            diagnostics: [
                DiagnosticSpec(message: "@ProtoField needs an integer literal field number", line: 3, column: 5)
            ], macros: macros)
    }

    @Test func `a class is refused`() {
        assertMacroExpansion(
            "@ProtoMessage\nclass M {}", expandedSource: "class M {}",
            diagnostics: [DiagnosticSpec(message: "@ProtoMessage only applies to a struct", line: 1, column: 1)],
            macros: macros)
    }

    @Test func `an array of optionals and an optional array are refused`() {
        expectError(
            "@ProtoMessage\nstruct M {\n    @ProtoField(1) var a: [Int32?] = []\n}",
            "'a': nested arrays and arrays of optionals have no protobuf form")
        expectError(
            "@ProtoMessage\nstruct M {\n    @ProtoField(1) var a: [Int32]? = nil\n}",
            "'a': an optional array or optional optional has no protobuf form")
    }

    @Test func `static, computed and lazy properties are not fields`() {
        assertMacroExpansion(
            "@ProtoMessage\nstruct M {\n    static var x = 1\n    var y: Int { 2 }\n    @ProtoField(1) var a: Int64 = 0\n}",
            expandedSource:
                """
                struct M {
                    static var x = 1
                    var y: Int { 2 }
                    @ProtoField(1) var a: Int64 = 0
                }

                extension M: AemiProtoFastEncodable, AemiProtoFastDecodable, Codable {
                    func __aepbEncode(into w: inout WireWriter) throws(WireError) {
                        if self.a != 0 {
                            w.appendTag(1, .varint)
                            w.appendVarint(UInt64(bitPattern: Int64(truncatingIfNeeded: self.a)))
                        }
                    }

                    static func __aepbDecode(from r: inout WireReader) throws(WireError) -> Self {
                        var result = Self()
                        try result.__aepbMerge(from: &r)
                        return result
                    }

                    mutating func __aepbMerge(from r: inout WireReader) throws(WireError) {
                        while let tag = try r.nextTag() {
                            switch (tag.fieldNumber.rawValue, tag.wireType) {
                            case (1, .varint):
                                self.a = Int64(truncatingIfNeeded: Int64(bitPattern: try r.readVarint()))
                            default:
                                try r.skipField(tag)
                            }
                        }
                    }

                    enum CodingKeys: Int, CodingKey {
                        case a = 1
                    }
                }
                """, macros: macros)
    }
}
