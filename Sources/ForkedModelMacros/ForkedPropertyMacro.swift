import SwiftSyntax
import SwiftSyntaxMacros

public enum MergeAlgorithm: String {
    case mergablePropertyAlgorithm
    case valueArray
}

public struct ForkedPropertyMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonVariable
        }
        return []
    }
}
