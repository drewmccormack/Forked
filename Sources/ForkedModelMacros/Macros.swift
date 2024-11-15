import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct ForkedModelPlugin: CompilerPlugin {
    var providingMacros: [Macro.Type] = [
        ForkedModelMacro.self,
        ForkedPropertyMacro.self,
    ]
}
