import Testing

@testable import AemiProtobufSchema

/// Roadmap 0002: the checks protoc makes. Each schema below is one protoc refuses, and the compiler refuses it too.
@Suite struct ProtoCompilerCheckTests {
    static let refused: [(String, String)] = [
        ("unknown type", #"syntax = "proto3"; message M { Missing m = 1; }"#),
        ("duplicate message", #"syntax = "proto3"; message M {} message M {}"#),
        ("duplicate field name", #"syntax = "proto3"; message M { int32 a = 1; int32 a = 2; }"#),
        ("duplicate field number", #"syntax = "proto3"; message M { int32 a = 1; int32 b = 1; }"#),
        ("reserved number", #"syntax = "proto3"; message M { reserved 1; int32 a = 1; }"#),
        ("reserved name", #"syntax = "proto3"; message M { reserved "a"; int32 a = 1; }"#),
        ("proto3 first enum value", #"syntax = "proto3"; enum E { A = 1; }"#),
        ("proto3 required", #"syntax = "proto3"; message M { required int32 a = 1; }"#),
        ("proto3 default", #"syntax = "proto3"; message M { int32 a = 1 [default = 2]; }"#),
        ("duplicate enum number", #"syntax = "proto3"; enum E { A = 0; B = 0; }"#),
        ("field number zero", #"syntax = "proto3"; message M { int32 a = 0; }"#),
        ("field number reserved for protobuf", #"syntax = "proto3"; message M { int32 a = 19000; }"#),
        ("map key type", #"syntax = "proto3"; message M { map<double, int32> m = 1; }"#),
        (
            "extension outside range",
            #"syntax = "proto2"; message M { extensions 10 to 20; } extend M { optional int32 x = 5; }"#
        ),
        ("unknown option", #"syntax = "proto3"; option no_such_option = 1;"#),
        ("option type", #"syntax = "proto3"; message M { int32 a = 1 [deprecated = 5]; }"#),
        ("missing import", #"syntax = "proto3"; import "nowhere.proto";"#),
        ("syntax error", #"syntax = "proto3"; message M { int32 a = ; }"#),
        ("label in oneof", #"syntax = "proto3"; message M { oneof o { repeated int32 a = 1; } }"#)
    ]

    @Test(arguments: refused.indices) func `protoc's refusals are refused`(index: Int) {
        let (what, text) = Self.refused[index]
        let compiler = ProtoCompiler { $0 == "input.proto" ? text : nil }
        #expect(throws: ProtoCompileError.self, "\(what)") { try compiler.compile(["input.proto"]) }
    }

    @Test func `an error names the file, line and column`() {
        let compiler = ProtoCompiler { $0 == "a.proto" ? "syntax = \"proto3\";\nmessage M {\n  int32 a = ;\n}\n" : nil }
        do {
            _ = try compiler.compile(["a.proto"])
            Issue.record("compiled")
        } catch {
            #expect(error.file == "a.proto" && error.line == 3)
        }
    }
}
