import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import AemiProtobufMacros

/// Every shape `@ProtoOneof` refuses is diagnosed, and nothing is generated for it (roadmap 0026).
struct ProtoOneofDiagnosticsTests {
    private let macros: [String: any Macro.Type] = ["ProtoOneof": ProtoOneofMacro.self]

    private func expectError(_ source: String, _ message: String, line: Int, column: Int) {
        SwiftSyntaxMacrosGenericTestSupport.assertMacroExpansion(
            source, expandedSource: source.replacing("@ProtoOneof\n", with: ""),
            diagnostics: [DiagnosticSpec(message: message, line: line, column: column)],
            macroSpecs: macros.mapValues { MacroSpec(type: $0) },
            failureHandler: { Issue.record("\($0.message)") })
    }

    @Test func `a struct is refused`() {
        expectError(
            "@ProtoOneof\nstruct K {}",
            "@ProtoOneof applies to an enumeration; mark the message property holding it @ProtoOneofField", line: 1,
            column: 1)
    }

    @Test func `a case without a number, with no value or two, or two cases in one declaration are refused`() {
        expectError("@ProtoOneof\nenum K {\n    case a(Int32)\n}", "'a' needs @ProtoField(number)", line: 3, column: 5)
        expectError(
            "@ProtoOneof\nenum K {\n    @ProtoField(1) case a\n}", "'a' needs exactly one associated value", line: 3,
            column: 5)
        expectError(
            "@ProtoOneof\nenum K {\n    @ProtoField(1) case a(Int32, Int32)\n}",
            "'a' needs exactly one associated value",
            line: 3, column: 5)
        expectError(
            "@ProtoOneof\nenum K {\n    @ProtoField(1) case a(Int32), b(Int32)\n}",
            "a oneof member is one case per declaration, with its own @ProtoField", line: 3, column: 5)
    }

    @Test func `a repeated value, a repeated number and a kind that does not fit are refused`() {
        expectError(
            "@ProtoOneof\nenum K {\n    @ProtoField(1) case a([Int32])\n}",
            "'a': a oneof member cannot be repeated, optional or a map", line: 3, column: 5)
        expectError(
            "@ProtoOneof\nenum K {\n    @ProtoField(1) case a(Int32)\n    @ProtoField(1) case b(Int32)\n}",
            "field number 1 is used by 'a' and 'b'", line: 4, column: 5)
        expectError(
            "@ProtoOneof\nenum K {\n    @ProtoField(1, .sint32) case a(String)\n}",
            "'a' is String, which cannot be a protobuf sint32; use Int32", line: 3, column: 5)
    }
}
