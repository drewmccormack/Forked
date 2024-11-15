import SwiftSyntax
import SwiftSyntaxMacros

public enum MergeAlgorithm {
    case valueArray
}

public struct ForkedPropertyMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonVariable
        }
        
        for binding in variableDecl.bindings {
            guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmed,
                  let type = binding.typeAnnotation?.type.trimmed
            else { continue }

            let forceEscaping = try node.extractEnumCaseArgument(named: "mergeAlgorithm")?.value == "true"
        }

        return []
    }
}
