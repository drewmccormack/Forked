import SwiftSyntax
import SwiftSyntaxMacros
import ForkedMerge

public struct MergablePropertyMacro: PeerMacro {
    
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let _ = declaration.as(VariableDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonVariable
        }
        
        return []
        
//        guard let alg = try variableDecl.propertyMerge(), alg.needsBackingType else { return [] }
//        
//        let propertyName = variableDecl.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
//        let originalType = variableDecl.bindings.first!.typeAnnotation!.type.trimmedDescription
//        let backingProperty: DeclSyntax =
//            """
//            private var _\(raw: propertyName) = Register<\(raw: originalType)>(.init())
//            """
//        
//        return [backingProperty]
    }
    
}
