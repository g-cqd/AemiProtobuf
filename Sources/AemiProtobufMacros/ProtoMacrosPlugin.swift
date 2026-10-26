import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ProtoMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [ProtoMessageMacro.self, ProtoFieldMacro.self]
}
