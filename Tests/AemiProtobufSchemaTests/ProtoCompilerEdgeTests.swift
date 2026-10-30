import Testing

@testable import AemiProtobufSchema

/// Roadmap 0002: the compiler's rarer paths. Escapes and number forms, message literals in all their shapes, option errors,
/// and import cycles.
@Suite struct ProtoCompilerEdgeTests {
    private func compile(_ files: [String: String], _ root: String = "a.proto") throws(ProtoCompileError)
        -> FileDescriptorSet
    {
        try ProtoCompiler { files[$0] }.compile([root])
    }

    private static let options = """
        syntax = "proto2";
        package e;
        import "google/protobuf/descriptor.proto";
        message Inner { optional int32 n = 1; repeated string s = 2; optional group G = 3 { optional int32 v = 1; } map<string, int32> m = 4; extensions 100 to 200; }
        extend Inner { optional bool flag = 100; }
        enum Kind { KIND_A = 0; KIND_B = 1; }
        extend google.protobuf.FileOptions {
          optional Inner inner = 51000;
          optional string text = 51001;
          optional bytes raw = 51002;
          optional float f = 51003;
          optional double d = 51004;
          optional uint64 u = 51005;
          optional sint32 s32 = 51006;
          optional Kind kind = 51007;
          repeated Inner many = 51008;
        }

        """

    @Test func `strings, numbers and message literals in every form`() throws {
        let source =
            Self.options + #"""
                option (text) = "\x41\101\u00e9\U0001F600\a\b\f\v\?\'\"" 'single';
                option (raw) = "\000\xff";
                option (f) = 1.5e3f;
                option (d) = -inf;
                option (u) = 0x7fffffffffffffff;
                option (s32) = -017;
                option (kind) = KIND_B;
                option (inner) = { n: 3 s: ["a", "b"] G < v: 2 > m { key: "k" value: 9 } [e.flag]: t };
                option (many) = { n: 1 };
                option (many) = { n: 2, s: "x"; };
                """#
        let set = try compile([
            "a.proto": source,
            "google/protobuf/descriptor.proto": ProtoCompilerCorpusTests.source("google/protobuf/descriptor.proto")
                ?? ""
        ])
        let file = try #require(set.files.last)
        let schema = DynamicSchema(set)
        let options = try schema.decode(try #require(file.options), as: "google.protobuf.FileOptions")
        let text = try #require(schema.messageType(named: "google.protobuf.FileOptions")?.field(named: "[e.text]"))
        #expect(options.fields[text.number] == .string("AAé😀\u{7}\u{8}\u{C}\u{B}?'\"single"))
        let inner = try #require(schema.messageType(named: "google.protobuf.FileOptions")?.field(named: "[e.inner]"))
        guard case .message(let value)? = options.fields[inner.number] else {
            Issue.record("no inner")
            return
        }
        #expect(value.fields[1] == .int32(3) && value.fields[2] == .list([.string("a"), .string("b")]))
        #expect(value.fields[4] == .map([.string("k"): .int32(9)]))
        let printed = ProtoPrinter(dependencies: set.files).print(file)
        let again = try compile([
            "a.proto": printed,
            "google/protobuf/descriptor.proto": ProtoCompilerCorpusTests.source("google/protobuf/descriptor.proto")
                ?? ""
        ])
        #expect(again.files.last == file)
    }

    @Test(arguments: [
        #"option (text) = 1;"#, #"option (u) = -1;"#, #"option (s32) = 99999999999;"#, #"option (kind) = KIND_C;"#,
        #"option (kind) = 1;"#, #"option (text) = "a"; option (text) = "b";"#, #"option (text).x = "a";"#,
        #"option (nowhere) = 1;"#, #"option (inner) = { nothing: 1 };"#, #"option (inner) = { n: "x" };"#,
        #"option (inner) = { n: 1 n: 2 };"#, #"option (f) = "x";"#, #"option (inner) = 3;"#, #"option (raw) = 1;"#,
        #"option (inner) = { [e.none]: 1 };"#, #"option (inner) = { G: 1 };"#, #"option (inner) = { n: 1"#
    ])
    func `options that do not fit are refused`(option: String) {
        let files = [
            "a.proto": Self.options + option,
            "google/protobuf/descriptor.proto": ProtoCompilerCorpusTests.source("google/protobuf/descriptor.proto")
                ?? ""
        ]
        #expect(throws: ProtoCompileError.self) { try compile(files) }
    }

    @Test(arguments: [
        "syntax = \"proto3\"; option java_package = \"a\\q\";", "syntax = \"proto3\"; option java_package = \"a",
        "syntax = \"proto3\"; /* open", "syntax = \"proto3\"; message M { int32 a = 0x; }",
        "syntax = \"proto3\"; message M { int32 a = 1x; }", "syntax = \"proto3\"; option java_package = \"\\u12\";",
        "syntax = \"proto3\"; option java_package = \"\\xg\";",
        "syntax = \"proto3\"; message M { double a = 1 [default = 1e]; }",
        "edition = \"1999\";", "syntax = \"proto3\"; syntax = \"proto3\";",
        "syntax = \"proto3\"; package a; package b;",
        "syntax = \"proto3\"; }", "syntax = \"proto3\"; message M {", "syntax = \"proto3\"; message M { oneof o { } }",
        "syntax = \"proto3\"; message M { map<string, int32> m = 1 [default = 1]; }",
        "syntax = \"proto2\"; message M { optional group lower = 1 {} }",
        "syntax = \"proto2\"; message M { repeated int32 a = 1 [default = 1]; }",
        "syntax = \"proto2\"; message M { optional M a = 1 [default = 1]; }",
        "edition = \"2023\"; message M { optional int32 a = 1; }",
        "syntax = \"proto2\"; message M { optional int32 a = 1 [json_name = 1]; }",
        "syntax = \"proto2\"; message M { extensions 1 to 10; } extend M { optional int32 a = 2 [json_name = \"x\"]; }",
        "syntax = \"proto3\"; service S { rpc M(Nope) returns (Nope); }",
        "syntax = \"proto2\"; extend Nope { optional int32 a = 1; }",
        "syntax = \"proto3\"; enum E { A = 0; reserved 1, 3 to 2; }",
        "syntax = \"proto3\"; enum E { A = 0; B = 1; reserved 1; }",
        "syntax = \"proto3\"; enum E { A = 0; reserved \"B\"; B = 1; }",
        "syntax = \"proto3\"; message M { int32 a = 1; extensions 1 to 5; }",
        "edition = \"2023\"; enum E { A = 1; }"
    ])
    func `malformed or inconsistent files are refused`(source: String) {
        #expect(throws: ProtoCompileError.self) { try compile(["a.proto": source]) }
    }

    @Test func `a file that imports itself through another is refused, and a missing root names itself`() {
        let files = [
            "a.proto": "syntax = \"proto3\"; import \"b.proto\";", "b.proto": "syntax = \"proto3\"; import \"a.proto\";"
        ]
        #expect(throws: ProtoCompileError.self) { try compile(files) }
        do {
            _ = try compile([:], "missing.proto")
        } catch {
            #expect(error.file == "missing.proto" && error.description.hasPrefix("missing.proto:0:0:"))
        }
    }

    @Test func `the parser on its own leaves names as written`() throws {
        let file = try ProtoParser().parse("syntax = \"proto3\"; message M { Other o = 1; }")
        #expect(file.messages.first?.fields.first?.typeName == "Other")
        #expect(throws: ProtoParseError.self) { try ProtoParser(maxSourceBytes: 3).parse("syntax = \"proto3\";") }
    }

    @Test func `floats are written as C's %g writes them`() {
        #expect(CFloatFormat.simple(7e22) == "7e+22")
        #expect(CFloatFormat.simple(Float(9e9)) == "9e+09")
        #expect(CFloatFormat.simple(0.1) == "0.1")
        #expect(CFloatFormat.simple(1.0 / 3.0) == "0.33333333333333331")
        #expect(CFloatFormat.simple(Float(-1.5e-7)) == "-1.5e-07")
        #expect(CFloatFormat.simple(123_456.0) == "123456")
        #expect(CFloatFormat.simple(Double.greatestFiniteMagnitude) == "1.7976931348623157e+308")
        #expect(CFloatFormat.simple(5e-324) == "4.94065645841247e-324")
        #expect(CFloatFormat.simple(-Double.nan) == "nan" && CFloatFormat.simple(-Double.infinity) == "-inf")
        #expect(CFloatFormat.g(0.0001, precision: 6) == "0.0001" && CFloatFormat.g(9.9999995, precision: 6) == "10")
    }
}
