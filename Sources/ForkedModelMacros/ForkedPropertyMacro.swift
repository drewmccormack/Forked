import SwiftSyntax
import SwiftSyntaxMacros
import ForkedMerge

public struct ForkedPropertyMacro: PeerMacro, AccessorMacro {
    
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonVariable
        }
        
        guard let alg = try variableDecl.propertyMergeAlgorithm(), alg.needsBackingType else { return [] }
        
        let propertyName = variableDecl.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
        let originalType = variableDecl.bindings.first!.typeAnnotation!.type.trimmedDescription
        let backingProperty: DeclSyntax =
            """
            private var _\(raw: propertyName) = Register<\(raw: originalType)>()
            """
        
        return [backingProperty]
    }
    
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonVariable
        }
        
        guard let alg = try variableDecl.propertyMergeAlgorithm(), alg.needsBackingType else { return [] }
        
        let propertyName = variableDecl.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
        let getter =
            """
            get {
                return _\(propertyName).value
            }
            """
        let setter =
            """
            set {
                _\(propertyName).value = newValue
            }
            """
        
        return [
            AccessorDeclSyntax(stringLiteral: getter),
            AccessorDeclSyntax(stringLiteral: setter)
        ]
    }
    
}
