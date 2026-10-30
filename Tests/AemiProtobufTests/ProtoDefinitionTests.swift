import AemiProtobuf
import AemiProtobufSchema
import Foundation
import Testing

extension Color: AemiProtoDefined {}
extension Shade: AemiProtoDefined {}

/// Roadmap 0005: the definition the macros write. `ProtoDefinitions.file(for:)` gathers a type's definition and every type it
/// reaches into one edition-2023 file; `ProtoCompiler` compiles it; a dynamic message of the compiled descriptor reads what the
/// macro wrote and writes bytes the macro reads back to the same value.
@Suite struct ProtoDefinitionTests {
    private func roundTrip<T: AemiProtoFastEncodable & AemiProtoFastDecodable & AemiProtoDefined & Equatable>(
        _ value: T, _ package: String
    ) throws {
        let text = try ProtoDefinitions.file(for: [T.self], package: package)
        let set = try ProtoCompiler { $0 == "defined.proto" ? text : nil }.compile(["defined.proto"])
        let schema = DynamicSchema(set)
        let bytes = try ProtobufEncoder().encodeToBytes(value)
        let message = try schema.decode(bytes, as: package + "." + T.protoName)
        let back = try ProtobufDecoder().decode(T.self, fromBytes: try schema.encode(message))
        #expect(back == value, "\(text)")
    }

    @Test func `a message's definition states every kind, presence and packing`() {
        let text = Kinds.protoDefinition
        #expect(text.hasPrefix("message Kinds {\n"))
        #expect(text.contains("  int32 aInt32 = 1 [features.field_presence = IMPLICIT];"))
        #expect(text.contains("  sint64 aSint64 = 6 [features.field_presence = IMPLICIT];"))
        #expect(text.contains("  Color color = 16 [features.field_presence = IMPLICIT];"))
        #expect(text.contains("  Leaf leaf = 17;"))
        #expect(text.contains("  int32 maybe = 18;"))
        #expect(text.contains("  repeated fixed64 rFixed64 = 21;"))
        #expect(Kinds.protoName == "Kinds")
        #expect(
            Color.protoDefinition.contains("COLOR_GREEN = 1;") && Color.protoDefinition.contains("enum_type = CLOSED"))
    }

    @Test func `the definitions compile, and dynamic messages of them read and write what the macro does`() throws {
        try roundTrip(Kinds.sample, "kinds")
        try roundTrip(Shape(kind: .leaf(Leaf(name: "x")), name: "s"), "shapes")
        try roundTrip(Maps.sample, "maps")
        try roundTrip(GroupHolder.sample, "groups")
        try roundTrip(RequiredHolder(a: 1, child: RequiredHolder(a: 2), many: [RequiredHolder(a: 3)]), "required")
    }

    @Test func `a type with no definition is named`() {
        #expect(throws: ProtoDefinitionError.self) { try ProtoDefinitions.file(for: [Int.self]) }
    }
}
