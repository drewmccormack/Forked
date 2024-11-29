import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct ForkedModelPlugin: CompilerPlugin {
    var providingMacros: [Macro.Type] = [
        ForkedModelMacro.self,
        MergeablePropertyMacro.self,
        BackedPropertyMacro.self,
    ]
}
