import AemiProtobufSchema
import Testing

struct ProtoParserMalformedTests {
    @Test(arguments: [
        "@", "/* never closed", "syntax = \"proto3", "syntax = \"proto3\"",
        "enum E { VALUE = 0;", "message M { @ }", "message M { string text = 4294967297; }",
        "message M { string text = 0; }", "message M { string text = 536870912; }",
        "message M { string text = 19000; }", "syntax = \"unknown\";",
        "syntax = \"proto\\3\";", "syntax = \"proto\n3\";"
    ])
    func `malformed proto input is rejected rather than repaired`(source: String) {
        #expect(throws: ProtoParseError.self) { try ProtoParser().parse(source) }
    }

    @Test func `source byte limit accepts its boundary and rejects an extra byte`() throws {
        let source = "message M {}"
        let sut = ProtoParser(maxSourceBytes: source.utf8.count)
        #expect(try sut.parse(source).messages.count == 1)
        #expect(throws: ProtoParseError.self) { try sut.parse(source + " ") }
    }

    @Test func `nesting limit accepts its boundary and rejects an extra message`() throws {
        let sut = ProtoParser(maxDepth: 1)
        #expect(try sut.parse("message M {}").messages.count == 1)
        #expect(throws: ProtoParseError.self) { try sut.parse("message M { message N {} }") }
        #expect(throws: ProtoParseError.self) { try ProtoParser(maxDepth: 0).parse("message M {}") }
    }

    @Test func `message nesting beyond the default limit is rejected`() {
        let source = String(repeating: "message M { ", count: 101) + String(repeating: "}", count: 101)
        #expect(throws: ProtoParseError.self) { try ProtoParser().parse(source) }
    }
}
