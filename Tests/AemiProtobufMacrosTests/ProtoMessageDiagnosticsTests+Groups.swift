import Foundation
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import AemiProtobufMacros

// Groups, required fields and packing. Apart from ProtoMessageDiagnosticsTests.swift to keep each file
// within the 250 lines SourceStructureTests allows.
extension ProtoMessageDiagnosticsTests {
    @Test func `a singular group, a required field that is not optional and a map of groups are refused`() {
        expectError(
            "@ProtoMessage\nstruct M {\n    @ProtoField(1, .group) var g: G = G()\n}",
            "'g': a group is optional or repeated, as proto2 declares it"
        )
        expectError(
            "@ProtoMessage\nstruct M {\n    @ProtoField(1, required: true) var a: Int32 = 0\n}",
            "'a': a required field is Optional in Swift, so its absence can be seen"
        )
        expectError(
            "@ProtoMessage\nstruct M {\n    @ProtoField(1, value: .group) var m: [Int32: G] = [:]\n}",
            "'m': a map value cannot be a group, and a map cannot be required"
        )
    }

    @Test func `packed: false on a field that is not a repeated number is refused`() {
        expectError(
            "@ProtoMessage\nstruct M {\n    @ProtoField(1, packed: false) var a: [String] = []\n}",
            "'a': packed: false is for a repeated number, bool or enumeration"
        )
    }
}
