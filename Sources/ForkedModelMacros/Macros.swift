import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct ForkedModelMacros: CompilerPlugin {
    var providingMacros: [Macro.Type] = [ModelMacro.self]
}
